#!/bin/bash
echo "===== Setting up Angular Frontend ====="

# Définir les chemins
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
projectName="angular-project"
projectDir="$scriptDir/$projectName"

# 1. Récupérer les données de l'API
apiUrl="http://localhost:3000/api/tablenames"
jsonFile="$(mktemp)"
curl -s "$apiUrl" -o "$jsonFile"
if [ $? -ne 0 ]; then
    echo "❌ Failed to retrieve data from the API!"
    exit 1
fi

# 2. Extraction des noms
items=()
mapfile -t items < <(jq -r '.[]' "$jsonFile" | tr -d '[]_-.`\'')  # Nettoyage des caractères spéciaux
rm "$jsonFile"

# Vérification
if [ ${#items[@]} -eq 0 ]; then
    echo "❌ No table names parsed!"
    exit 1
fi

# 3. Créer le projet Angular si non existant
if [ ! -d "$projectDir" ]; then
    echo "📦 Creating Angular project..."
    ng new "$projectName" --routing --style=scss --skip-install --defaults
    cd "$projectDir" || exit 1

    # === styles.scss ===
    cat <<EOF > src/styles.scss
body {
  background: #d9ecff;
  margin: 0;
  padding: 0;
  font-family: Arial, sans-serif;
}
EOF

    # === app.config.ts ===
    cat <<EOF > src/app/app.config.ts
import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { routes } from './app.routes';
import { provideHttpClient } from '@angular/common/http';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideHttpClient()
  ]
};
EOF

    # === app.routes.ts ===
    {
        echo "//app.routes"
        echo "import { Routes } from '@angular/router';"
        echo "import { AdminComponent } from './admin/admin.component';"
        echo "import { SidebarComponent } from './sidebar/sidebar.component';"
        echo "import { UpdateComponent } from './update/update.component';"
        for name in "${items[@]}"; do
            echo "import { ${name}Component } from './${name}/${name}.component';"
        done
        echo "export const routes: Routes = ["
        for name in "${items[@]}"; do
            echo "  { path: '$name', component: ${name}Component },"
        done
        echo "  { path: 'admin', component: AdminComponent },"
        echo "  { path: 'sidebar', component: SidebarComponent },"
        echo "  { path: 'update/:table/:id', component: UpdateComponent },"
        echo "  { path: '', redirectTo: '/admin', pathMatch: 'full' }"
        echo "];"
    } > src/app/app.routes.ts

    # === app.component.html ===
    {
        echo "<div class=\"layout\">"
        echo "  <app-sidebar></app-sidebar>"
        echo "  <div class=\"content\">"
        echo "    <nav>"
        echo "      <a routerLink=\"/admin\" routerLinkActive=\"active-link\"></a>"
        for name in "${items[@]}"; do
            echo "      <a routerLink=\"/$name\"></a>"
        done
        echo "      <!-- Search Bar -->"
        echo "      <input type=\"text\" placeholder=\"🔍Search...\" class=\"search-bar\" />"
        echo "    </nav>"
        echo "    <router-outlet></router-outlet>"
        echo "  </div>"
        echo "</div>"
    } > src/app/app.component.html

    # === app.component.ts ===
    {
        echo "import { Component } from '@angular/core';"
        echo "import { RouterOutlet } from '@angular/router';"
        echo "import { AdminComponent } from './admin/admin.component';"
        echo "import { SidebarComponent } from './sidebar/sidebar.component';"
        for name in "${items[@]}"; do
            echo "import { ${name}Component } from './${name}/${name}.component';"
        done
        echo "@Component({"
        echo "  selector: 'app-root',"
        echo "  standalone: true,"
        echo "  imports: ["
        for name in "${items[@]}"; do
            echo "    ${name}Component,"
        done
        echo "    AdminComponent,"
        echo "    SidebarComponent,"
        echo "    RouterOutlet"
        echo "  ],"
        echo "  templateUrl: './app.component.html',"
        echo "  styleUrls: ['./app.component.scss']"
        echo "})"
        echo "export class AppComponent {"
        echo "  title = 'user-test';"
        echo "}"
    } > src/app/app.component.ts

    # === app.component.scss ===
    cat <<EOF > src/app/app.component.scss
/* General Layout */
.layout {
    display: flex;
    height: 100vh;
    margin: 0;
    padding: 0;
    background-color: #d9ecff;
    .content {
        flex: 1;
        margin-left: 200px;
        padding: 30px;
    }
    .search-bar {
        padding: 8px 16px;
        margin-left: auto;
        border-radius: 50px;
        border: 1px solid #ccc;
        font-size: 14px;
        width: 220px;
        outline: none;
        background-color: #fff;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
}
@media (max-width: 768px) {
    .layout {
        flex-direction: column;
        .sidebar {
            position: relative;
            width: 100%;
            flex-direction: row;
            padding: 10px;
            h2 { font-size: 18px; margin: 0 10px 0 0; }
            nav ul { display: flex; justify-content: space-around; flex: 1; li { margin: 0; } }
        }
        .content {
            margin: 0;
            padding: 10px;
            .top-nav { flex-wrap: wrap; a { margin: 5px; font-size: 14px; } }
        }
    }
}
@media (max-width: 480px) {
    .layout {
        .sidebar { display: none; }  /* hide sidebar entirely */
        .content {
            margin: 0;
            .top-nav {
                justify-content: center;
                a { flex: 1 0 45%; text-align: center; padding: 8px; font-size: 13px; }
            }
        }
    }
}
EOF

    echo "✅ Angular project \"$projectName\" created successfully."
    cd "$projectDir" || exit 1
else
    echo "ℹ️ Angular project already exists."
    cd "$projectDir" || exit 1
fi

# 🔁 Génération de composants (prochaine étape du script)
echo "===== Generating components  ====="
ng g c sidebar
ng g c admin
ng g c update

# Creating admin.component.html
cat > src/app/admin/admin.component.html <<EOF
<div class="admin-dashboard">
  <p>⚙️Admin Dashboard</p>
  <table border="1">
    <thead>
      <tr>
        <th>Table Name</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr *ngFor="let table of tables">
        <td>{{ table }}</td>
        <td>
          <button (click)="viewTable(table)" class="btn">
            <i class="fas fa-eye"></i> View
          </button>
          <button (click)="deleteTable(table)" class="btn">
            <i class="fas fa-trash-alt"></i> Delete
          </button>
        </td>
      </tr>
    </tbody>
  </table>
</div>
EOF

# Creating admin.component.scss
cat > src/app/admin/admin.component.scss <<EOF
/* admin styling */
.admin-dashboard {
  background: #edf6ff;
  margin: 20px auto;
  max-width: 80%;
  padding: 30px;
  border-radius: 19px;
  box-shadow: 0 4px 8px rgba(0,0,0,0.1);
  p {
    text-align: center;
    font: bold 28px Arial, sans-serif;
    margin-bottom: 20px;
    color: #34495e;
  }
  table {
    width: 100%;
    margin-top: 10px;
    border-collapse: collapse;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    thead {
      background: #014e85;
      color: #fff;
      th {
        padding: 12px 16px;
        font-size: 16px;
        &:nth-child(2) { text-align: center; }
      }
    }
    tbody {
      tr {
        transition: background .2s;
        &:nth-child(even) { background: #f9f9f9; }
        &:hover { background: #eaf2f8; }
        td {
          padding: 12px 16px;
          font-size: 14px;
          border-bottom: 1px solid #ddd;
          &:nth-child(2) { text-align: center; }
        }
      }
    }
  }
  .btn {
    background: #d6eaff;
    color: #34495e;
    border: 1px solid #a9d5ff;
    padding: 7px 55px;
    font-size: 14px;
    border-radius: 6px;
    cursor: pointer;
    transition: .3s;
    margin: 0 6px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    i { font-size: 16px; }
    &:hover {
      background: #b8d8ff;
      transform: translateY(-2px);
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    & + & { margin-left: 12px; }
  }
  @media (max-width: 768px) {
    padding: 10px;
    margin: 10px;
    p { font-size: 24px; }
    table {
      thead th, tbody td {
        padding: 8px 10px;
        font-size: 13px;
      }
    }
    .btn {
      display: block;
      width: 100%;
      margin: 5px 0;
    }
  }
}
EOF

# Creating admin.component.ts
cat > src/app/admin/admin.component.ts <<EOF
import { Component, OnInit } from '@angular/core';
import { SharedService } from '../services/shared.service';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './admin.component.html',
  styleUrls: ['./admin.component.scss']
})
export class AdminComponent implements OnInit {
  tables: string[] = [];
  dataMap: any = {};

  constructor(private service: SharedService, private router: Router) {}

  ngOnInit(): void {
    this.service.getUsers().subscribe(data => {
      console.log("Données reçues:", data);
      if (data && typeof data === "object") {
        this.tables = Object.keys(data);
        this.dataMap = data;
      }
    });
  }

  viewTable(table: string): void {
    this.router.navigate(['/commentaires', table]);
  }

  deleteTable(table: string): void {
    this.service.deleteTable(table).subscribe(() => {
      this.tables = this.tables.filter(t => t !== table);
    });
  }
}
EOF

echo "✅ Admin component files created successfully."
# Creating sidebar.component.scss
echo "Creating sidebar.component.scss"
mkdir -p src/app/sidebar

cat <<EOF > src/app/sidebar/sidebar.component.scss
/* Sidebar Styling */
.sidebar {
    width: 200px;
    height: 100vh;
    background: #014e85;
    color: #ecf0f1;
    position: fixed;
    top: 0;
    left: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 16px 0;
    box-shadow: 2px 0 8px rgba(0, 0, 0, 0.25);
    h2 {
        font-size: 18px;
        margin: 0 0 16px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    nav ul {
        list-style: none;
        padding: 0;
        width: 100%;
        display: flex;
        flex-direction: column;
        li {
            margin: 10px 0;
            a {
                display: block;
                padding: 8px 14px;
                text-decoration: none;
                color: inherit;
                font-size: 14px;
                border-radius: 6px;
                transition: background 0.3s;
                &:hover, &.active-link { background: #1a4d75; }
            }
            .nav-button {
                display: block;
                padding: 8px 14px;
                background: #fff;
                color: #014e85;
                border: none;
                border-radius: 30px;
                font-size: 14px;
                cursor: pointer;
                width: 100%;
                text-align: left;
                box-shadow: 0 2px 5px rgba(0, 0, 0, 0.15);
                transition: 0.3s;
                &:hover {
                    background: #ecf0f1;
                    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
                }
            }
        }
    }
}

@media (max-width: 768px) {
    .sidebar {
        width: 100%;
        height: auto;
        position: relative;
        flex-direction: row;
        padding: 10px;
        h2 { font-size: 16px; margin: 0 12px 0 0; }
        nav ul {
            flex-direction: row;
            justify-content: space-around;
            li {
                margin: 0;
                a {
                    padding: 8px 10px;
                    font-size: 13px;
                }
                .nav-button {
                    padding: 8px 10px;
                    font-size: 13px;
                    border-radius: 20px;
                }
            }
        }
    }
}

@media (max-width: 480px) {
    .sidebar {
        flex-wrap: wrap;
        padding: 8px;
        h2 { display: none; }
        nav ul {
            flex-wrap: wrap;
            li {
                flex: 1 0 50%;
                a { padding: 6px; font-size: 12px; }
                .nav-button {
                    padding: 6px;
                    font-size: 12px;
                    border-radius: 20px;
                }
            }
        }
    }
}
EOF

# Creating sidebar.component.ts
echo "Creating sidebar.component.ts"
cat <<EOF > src/app/sidebar/sidebar.component.ts
import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { Router } from '@angular/router';

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './sidebar.component.html',
  styleUrl: './sidebar.component.scss'
})
export class SidebarComponent {
  constructor(private router: Router) {}

  navigateToDashboard() {
    this.router.navigate(['/admin']);
  }
}
EOF

# Liste des composants à générer
items=("admin" "update" "commentaires")

for i in "${items[@]}"
do
  echo "Generating component: $i"
  ng g c "$i" --standalone

  # Remplacer le contenu du fichier component.ts généré
  cat <<EOF > src/app/$i/$i.component.ts
import { Component, OnInit } from '@angular/core';
import { SharedService } from '../services/shared.service';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';

@Component({
  selector: 'app-$i',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './$i.component.html',
  styleUrls: ['./$i.component.scss']
})
export class ${i^}Component implements OnInit {
  constructor(private service: SharedService, private router: Router) {}

  ngOnInit(): void {
    // Initialization logic here
  }
}
EOF
