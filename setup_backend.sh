#!/bin/bash

echo "===== Initialisation du backend Node.js avec MongoDB ====="
# Vérification de l'installation de Node.js
if ! command -v node &> /dev/null; then
    echo "Node.js n'est pas installé. Veuillez l'installer depuis https://nodejs.org/"
    exit 1
fi

# Définition des répertoires
BACKEND_DIR="$ROOT_DIR%/backend"
CONFIG_DIR="$BACKEND_DIR/Config"
ROUTES_DIR="$BACKEND_DIR/Routes"

# Création des répertoires
mkdir -p "$CONFIG_DIR" "$ROUTES_DIR"

# Capture des paramètres
DB_URI="$1"
DB_NAME="$2"
USERNAME="$3"
PASSWORD="$4"
PORT="${5:-3000}"  # Port par défaut : 3000
ROOT_DIR="$6"
# Affichage des paramètres pour vérification
echo "DB_URI: $DB_URI"
echo "DB_NAME: $DB_NAME"
echo "USERNAME: $USERNAME"
echo "PASSWORD: $PASSWORD"
echo "PORT: $PORT"

# Création du fichier package.json
cat > "$BACKEND_DIR/package.json" <<EOF
{
  "name": "backend",
  "version": "1.0.0",
  "main": "index.js",
  "type": "commonjs",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongodb": "^5.5.0",
    "cors": "^2.8.5"
  }
}
EOF


# Création du fichier index.js
cat > "$BACKEND_DIR/index.js" <<EOF
const express = require('express');
const cors = require('cors');
const app = express();
const apiRoutes = require('./Routes/routes.js');

app.use(express.json());
app.use(cors());
app.use('/api', apiRoutes);

app.listen($PORT, () => console.log('Serveur démarré sur http://localhost:$PORT'));
EOF

# Création du fichier dbConnection.js
cat > "$CONFIG_DIR/dbConnection.js" <<EOF
const { MongoClient } = require('mongodb');
let client;

async function connect({
  host = '$DB_URI',
  dbName = '$DB_NAME',
  USER = '$USERNAME',
  PASS = '$PASSWORD'
}) {
  const auth = USER && PASS ? \`\${encodeURIComponent(USER)}:\${encodeURIComponent(PASS)}@\` : '';
  const uri = \`mongodb+srv://\${auth}\${host}/\${dbName}?retryWrites=true&w=majority\`;
  console.log(\`Connexion à MongoDB Atlas sur \${uri}\`);

  try {
    if (client) {
      console.log('Fermeture de la connexion précédente');
      await client.close();
    }

    client = await MongoClient.connect(uri, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });

    console.log('Connexion établie à MongoDB');
    return client.db(dbName);
  } catch (err) {
    console.error('Échec de la connexion :', err.message);
    throw err;
  }
}

module.exports = { connect };
EOF

# Création du fichier services.js
cat > "$CONFIG_DIR/services.js" <<EOF
const { connect } = require('./dbConnection.js');
const { MongoClient, ObjectId } = require('mongodb');

const connectionParams = {
  host: '$DB_URI',
  dbName: '$DB_NAME',
  USER: '$USERNAME',
  PASS: '$PASSWORD'
};

async function fetchData() {
  const db = await connect(connectionParams);
  const data = {};
  for (const { name } of await db.listCollections().toArray()) {
    data[name] = await db.collection(name).find().toArray();
  }
  return data;
}

async function getTableNames() {
  return (await (await connect(connectionParams))
    .listCollections().toArray()).map(c => c.name);
}

async function getItemById(collection, id) {
  const db = await connect(connectionParams);
  return db.collection(collection).findOne({ _id: new ObjectId(id) });
}

async function updateItemById(collection, id, updateFields) {
  const db = await connect(connectionParams);
  delete updateFields._id;
  return db
    .collection(collection)
    .updateOne(
      { _id: new ObjectId(id) },
      { \$set: updateFields }
    );
}

async function deleteItemById(collection, id) {
  const db = await connect(connectionParams);
  return db.collection(collection).deleteOne({ _id: new ObjectId(id) });
}

async function deleteCollectionByName(collectionName) {
  const db = await connect(connectionParams);
  return db.collection(collectionName).drop();
}

module.exports = {
  fetchData,
  getTableNames,
  updateItemById,
  deleteItemById,
  deleteCollectionByName,
  getItemById
};
EOF

# Création du fichier routes.js
cat > "$ROUTES_DIR/routes.js" <<EOF
const express = require('express');
const router = express.Router();
const {
  fetchData,
  getTableNames,
  updateItemById,
  deleteItemById,
  deleteCollectionByName,
  getItemById
} = require('../Config/services.js');

router.get('/getall', (req, res) =>
  fetchData().then(data => res.json(data)).catch(err => res.status(500).send('Erreur'))
);

router.get('/tablenames', async (req, res) => {
  try {
    const names = await getTableNames();
    console.log(names);
    res.json(names);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

router.get('/:table/:id', async (req, res) => {
  const { table, id } = req.params;
  try {
    const item = await getItemById(table, id);
    if (!item) {
      return res.status(404).json({ error: 'Élément non trouvé' });
    }
    res.json(item);
  } catch (err) {
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

router.put('/update/:table/:id', async (req, res) => {
  try {
    console.log('Requête PUT /update', req.params, 'corps:', req.body);
    const result = await updateItemById(req.params.table, req.params.id, req.body);
    const success = result.modifiedCount > 0;
    res.json({ success, matched: result.matchedCount, modified: result.modifiedCount });
  } catch (err) {
    console.error('Erreur lors de la mise à jour:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

router.delete('/delete/:table/:id', (req, res) => {
  deleteItemById(req.params.table, req.params.id)
    .then(result => res.json(result))
    .catch(err => res.status(500).json({ error: err.message }));
});

router.delete('/delete/:table', async (req, res) => {
  try {
    await deleteCollectionByName(req.params.table);
    res.json({ message: \`\${req.params.table} collection supprimée avec succès\` });
  } catch (err) {
    res.status(500).json({ error: 'Échec de la suppression de la collection' });
  }
});

module.exports = router;
EOF

# Installation des dépendances
cd "$BACKEND_DIR" || exit 1
echo "Installation des dépendances..."
npm install express mongodb cors

# Démarrage du serveur
echo "Démarrage du serveur Node.js..."
node index.js


