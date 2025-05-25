#!/bin/bash

echo "===== Setting up Node.js Backend Mysql ====="
# Vérification de l'installation de Node.js
if ! command -v node &> /dev/null; then
      "Node.js n'est pas installé. Veuillez l'installer depuis https://nodejs.org/"
    exit 1
fi

# Génération d'un timestamp unique
timestamp=$(date +"%Y%m%d_%H%M%S")

# Définition des répertoires
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
PROJET_DIR="$PARENT_DIR/projet"
BACKEND_DIR="$PROJET_DIR/backend_$timestamp"

CONFIG_DIR="$BACKEND_DIR/Config"
ROUTES_DIR="$BACKEND_DIR/Routes"

# Création des répertoires
mkdir -p "$CONFIG_DIR" "$ROUTES_DIR"

# Capture des paramètres
export DB_URI="$1"
export DB_NAME="$2"
export USERNAME="$3"
export PASSWORD="$4"
export PORT="${5:-3306}"  # Port par défaut : 3000
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
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.14.1",
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
app.listen(3000, () => console.log('Server running on http://localhost:3000'));
EOF
# Création du fichier dbConnection.js
cat > "$CONFIG_DIR/dbConnection.js" <<EOF
const mysql = require('mysql2/promise');
// Use environment variables
const USER = process.env.USERNAME || 'root';
const PASS = process.env.PASSWORD || '';
const HOST = process.env.DB_URI || 'localhost';
const DB_NAME = process.env.DB_NAME || 'test';
const PORT = process.env.PORT || 3306;
let connection;

async function connect() {
  try {
    if (connection && connection.connection && connection.connection.state !== 'disconnected') {
      return connection;
    }

    console.log(`Connecting to MySQL at '${host}:${port}', database: '${dbName}'`);

    connection = await mysql.createConnection({
      host: HOST,
      port: PORT,
      user: USER,
      password: PASS,
      database: DB_NAME
    });

    console.log('→ MySQL connection established');
    return connection;
  } catch (err) {
    console.error('Connection failed:', err);
  }
}

module.exports = { connect };

EOF


# Création du fichier services.js
cat > "$CONFIG_DIR/services.js" <<'EOF'
const { connect } = require('./dbConnection.js'); // import connect function

// Fetch all data from all tables  
async function fetchData() { 
      const conn = await connect({ host:'$DB_URI', port: '$PORT' , dbName: '$DB_NAME', });  
    const [tables] = await conn.query("SHOW TABLES");  
  const data = {}; 
  for (const row of tables) { 
    const tableName = Object.values(row)[0]; 
    const [rows] = await conn.query(`SELECT * FROM \`${tableName}\``); 
    const formattedRows = rows.map(item => {  
      if ('id' in item) {  
        const { id, ...rest } = item; 
        return { ...rest, _id: id };  
      }  
      return item;  
    }); 
    data[tableName] = formattedRows;  
  }  
  return data;   
} 

// Fetch all table names 
async function getTableNames() { 
  const conn = await connect({ host:'$DB_URI', port: '$PORT', dbName: '$DB_NAME', });
  const [results] = await conn.query('SHOW TABLES'); 
  return results.map(row => Object.values(row)[0]); 
}  

// Fetch a single item by its ID from a specific table  
async function getItemById(table, id) { 
  const conn = await connect({ host:'$DB_URI', port: '$PORT' , dbName: '$DB_NAME', });
  const [rows] = await conn.query(`SELECT * FROM \`${table}\` WHERE id = ?`, [id]);  
  if (rows[0]) {  
     const { id, ...rest } = rows[0];  
     return { ...rest, _id: id }; 
  }  
  return null;  
} 

// Update a specific item by its ID 
async function updateItemById(table, id, updateFields) {  
  const conn = await connect({ host:'$DB_URI', port: '$PORT', dbName: '$DB_NAME', });
  const keys = Object.keys(updateFields); 
  const values = Object.values(updateFields); 
  const cleanKeys = [];  
  const cleanValues = []; 
  for (let i = 0; i < keys.length; i++) { 
    if (keys[i] !== '_id') { 
      cleanKeys.push(keys[i]);  
      cleanValues.push(values[i]); 
    } 
  } 
  if (cleanKeys.length === 0) return null; 
  const setClause = cleanKeys.map(key => `\`${key}\` = ?`).join(', '); 
  const sql = `UPDATE \`${table}\` SET ${setClause} WHERE id = ?`;  
  const [result] = await conn.query(sql, [...cleanValues, id]);               
  return result;  
} 

// Delete an item by its ID  
async function deleteItemById(table, id) {  
  const conn = await connect({ host:'$DB_URI', port: '$PORT', dbName: '$DB_NAME', });
  const [result] = await conn.query(`DELETE FROM \`${table}\` WHERE id = ?`, [id]); 
  return result;   
} 

// Drop a complete table from the database 
async function deleteTableByName(tableName) { 
  const conn = await connect({ host:'$DB_URI', port: '$PORT', dbName: '$DB_NAME', });
  const [result] = await conn.query(`DROP TABLE \`${tableName}\``);
  return result;  
} 

module.exports = {
  fetchData,
  getTableNames,
  getItemById,
  updateItemById,
  deleteItemById,
  deleteTableByName
};
EOF

# Création du fichier routes.js
cat > "$ROUTES_DIR/routes.js" <<EOF
const express = require('express');
const router = express.Router();
const {fetchData, getTableNames, getItemById, updateItemById,deleteItemById,deleteTableByName} = require('../Config/services');

router.get('/getall', async (req, res) => {
try {
    const data = await fetchData();
    res.json(data);
} catch (err) {
  console.error('Error fetching data:', err);
  res.status(500).json({ error: 'Server error while fetching data' });
}
});
//route to get the table names
router.get('/tablenames', async (req, res) => {
  try {
    const names = await getTableNames();
    console.log(names);
    res.json(names);
  } catch (err) {
    console.error('Error fetching table names:', err);
    res.status(500).json({ error: 'Server error while fetching table names' });
  }
});

router.get('/:table/:id', async (req, res) => {
  const { table, id } = req.params;
  try {
    const item = await getItemById(table, id);
    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }
    res.json(item);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.put('/update/:table/:id', async (req, res) => {
const { table, id } = req.params;
  try {
    const result = await updateItemById(table, id, req.body);
    res.json({ success: result.affectedRows > 0, result });
  } catch (err) {
    console.error('Error updating item:', err);
    res.status(500).json({ error: 'Server error while updating item' });
  }
});
router.delete('/delete/:table/:id', async (req, res) => {
    const { table, id } = req.params; 
    try { 
      const result = await deleteItemById(table, id);
      res.json({ success: result.affectedRows > 0 });
    } catch (err) {
        console.error('Error deleting item:', err); 
        res.status(500).json({ error: 'Server error while deleting item' });  
    }
});
router.delete('/delete/:table', async (req, res) => {
  const { table } = req.params;
  try {
    await deleteTableByName(table);
    res.json({ message: 'Table ${table} deleted successfully' });
  } catch (err) {
    console.error('Error deleting table:', err);
    res.status(500).json({ error: 'Server error while deleting table' }); 
  }
});
module.exports = router;
EOF
# Installation des dépendances
cd "$BACKEND_DIR" || exit 1
echo "Installation des dépendances..."
npm install express mysql2 cors

# Démarrage du serveur
echo "Démarrage du serveur Node.js..."
node index.js
