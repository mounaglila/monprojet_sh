#!/bin/bash

echo "===== Setting up Angular Frontend ====="

# Définir les chemins
ROOT_DIR="$1"
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
projectDir="$scriptDir/angular-project"
projectName="angular-project"
FRONTEND_DIR="$ROOT_DIR%"
# API et fichier temporaire
apiUrl="http://localhost:3000/api/tablenames"
jsonFile="/tmp/tablenames.json"

# Récupération silencieuse des données
curl -s "$apiUrl" > "$jsonFile"

# Vérifier si le JSON est valide
if ! jq . "$jsonFile" >/dev/null 2>&1; then
    echo "Invalid JSON returned by the API!"
    cat "$jsonFile"  # Affiche le contenu pour debug
    rm "$jsonFile"
    exit 1
fi

# Extraire les noms de tables
items=$(jq -r '.[]' "$jsonFile" | sed 's/[\[\]_-]//g' | tr '\n' ' ')

# Vérification de la liste extraite
if [ -z "$items" ]; then
    echo "Failed to parse table names from the API!"
    rm "$jsonFile"
    exit 1
fi

# Nettoyage
rm "$jsonFile"

# Créer le projet Angular si nécessaire
if [ ! -d "$projectDir" ]; then
    echo "Creating Angular project..."
    ng new "$projectName" --routing --style=scss --skip-install --defaults
    cd "$projectDir"
else
    echo "Angular project already exists!"
    cd "$projectDir"
fi

# Create styles.scss
cat > src/styles.scss << 'EOL'
body {
    background: #d9ecff;
    margin: 0;
    padding: 0;
    font-family: Arial, sans-serif;
}
EOL

# Create app.config.ts
cat > src/app/app.config.ts << 'EOL'
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
EOL

# Create app.routes.ts
cat > src/app/app.routes.ts << 'EOL'
import { Routes } from '@angular/router';
import { AdminComponent } from './admin/admin.component';
import { SidebarComponent } from './sidebar/sidebar.component';
import { UpdateComponent } from './update/update.component';
EOL

# Add dynamic imports for each table
for item in $items; do
    echo "import { ${item}Component } from './${item}/${item}.component';" >> src/app/app.routes.ts
done

# Add routes configuration
cat >> src/app/app.routes.ts << 'EOL'
export const routes: Routes = [
EOL

# Add dynamic routes for each table
for item in $items; do
    echo "  { path: '$item', component: ${item}Component }," >> src/app/app.routes.ts
done

# Add remaining routes
cat >> src/app/app.routes.ts << 'EOL'
  { path: 'admin', component: AdminComponent },
  { path: 'sidebar', component: SidebarComponent},
  { path: 'update/:table/:id', component: UpdateComponent },
  { path: '', redirectTo: '/admin', pathMatch: 'full' }
];
EOL

# Create app.component.html
cat > src/app/app.component.html << 'EOL'
<div class="layout">
    <app-sidebar></app-sidebar>
    <div class="content">
        <nav>
            <a routerLink="/admin" routerLinkActive="active-link"></a>
EOL

# Add dynamic navigation links
for item in $items; do
    echo "            <a routerLink=\"/$item\"></a>" >> src/app/app.component.html
done

# Complete app.component.html
cat >> src/app/app.component.html << 'EOL'
            <!-- Search Bar -->
            <input type="text" placeholder="🔍Search..." class="search-bar" />
        </nav>
        <router-outlet></router-outlet>
    </div>
</div>
EOL

# Create app.component.ts
cat > src/app/app.component.ts << 'EOL'
import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { AdminComponent } from './admin/admin.component';
import { SidebarComponent } from './sidebar/sidebar.component';
EOL

# Add dynamic imports
for item in $items; do
    echo "import { ${item}Component } from './${item}/${item}.component';" >> src/app/app.component.ts
done

# Complete app.component.ts
cat >> src/app/app.component.ts << 'EOL'
@Component({
    selector: 'app-root',
    standalone: true,
    imports: [
EOL

# Add dynamic component imports
for item in $items; do
    echo "        ${item}Component," >> src/app/app.component.ts
done

cat >> src/app/app.component.ts << 'EOL'
        AdminComponent,
        SidebarComponent,
        RouterOutlet
    ],
    templateUrl: './app.component.html',
    styleUrls: ['./app.component.scss']
})
export class AppComponent {
    title = 'user-test';
}
EOL

# Create app.component.scss
cat > src/app/app.component.scss << 'EOL'
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
        .sidebar { display: none; }
        .content {
            margin: 0;
            .top-nav {
                justify-content: center;
                a { flex: 1 0 45%; text-align: center; padding: 8px; font-size: 13px; }
            }
        }
    }
}
EOL

# Generate components
echo "===== Generating components based on the list ====="
ng g c sidebar
ng g c admin
ng g c update

# Create admin component files
cat > src/app/admin/admin.component.html << 'EOL'
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
EOL

# Create admin component SCSS
cat > src/app/admin/admin.component.scss << 'EOL'
/* admin styling*/
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
EOL

# Create admin component TS
cat > src/app/admin/admin.component.ts << 'EOL'
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
            } else {
                this.tables = [];
                this.dataMap = {};
            }
        });
    }

    viewTable(table: string): void {
        const route = `/${table.toLowerCase()}`;
        this.router.navigate([route]);
    }

    deleteTable(table: string): void {
        if (confirm(`Es-tu sûr de vouloir supprimer '${table}' ?`)) {
            this.service.deleteTable(table).subscribe(
                (response) => {
                    console.log('Table supprimée:', response);
                    this.tables = this.tables.filter(t => t !== table);
                    delete this.dataMap[table];
                    alert(`Table ${table} supprimée avec succès !`);
                },
                (error) => {
                    console.error('Erreur lors de la suppression de la table:', error);
                    alert(`Erreur lors de la suppression de la table '${table}'`);
                }
            );
        }
    }
}
EOL

# Create sidebar component files
cat > src/app/sidebar/sidebar.component.html << 'EOL'
<div class="sidebar">
    <h2>Admin Panel</h2>
    <nav>
        <ul>
            <li><button (click)="navigateToDashboard()" class="nav-button">🛠️Dashboard</button></li>
        </ul>
    </nav>
</div>
EOL

# Create sidebar component SCSS
cat > src/app/sidebar/sidebar.component.scss << 'EOL'
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
EOL

# Create sidebar component TS
cat > src/app/sidebar/sidebar.component.ts << 'EOL'
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
EOL

# Generate components for each table
for item in $items; do
    echo "Generating component $item"
    ng g c "$item" --standalone

    # Create component TS file
    cat > "src/app/$item/$item.component.ts" << EOL
import { Component, OnInit } from '@angular/core';
import { SharedService } from '../services/shared.service';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';

@Component({
    selector: 'app-$item',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './$item.component.html',
    styleUrls: ['./$item.component.scss']
})
export class ${item}Component implements OnInit {
    tables: string[] = [];
    dataMap: any = {};

    constructor(private service: SharedService, private router: Router) {}

    ngOnInit(): void {
        this.service.getUsers().subscribe(data => {
            console.log("Données reçues:", data);
            if (data && typeof data === "object") {
                this.tables = Object.keys(data);
                this.dataMap = data;
            } else {
                this.tables = [];
                this.dataMap = {};
            }
        });
    }

    getColumns(table: string): string[] {
        return this.dataMap[table] && this.dataMap[table].length > 0
            ? Object.keys(this.dataMap[table][0]) : [];
    }

    getValues(row: any): any[] {
        return Object.values(row);
    }

    view${item}($item: any): void {
        console.log('View $item:', $item);
        alert(\`Viewing $item: \${JSON.stringify($item, null, 2)}\`);
    }

    update${item}($item: any): void {
        this.router.navigate(['/update', '$item', $item._id]);
    }

    delete${item}(${item}Id: string): void {
        console.log('Delete $item ID:', ${item}Id);
        this.service.deleteItem('$item', ${item}Id).subscribe(
            response => {
                console.log('$item deleted successfully', response);
                this.dataMap['$item'] = this.dataMap['$item'].filter(($item: any) => $item._id !== ${item}Id);
                alert('$item Deleted!');
            },
            error => {
                console.error('Error deleting $item:', error);
                alert('Failed to delete $item!');
            }
        );
    }
}
EOL

    # Create component HTML file
    cat > "src/app/$item/$item.component.html" << EOL
<p>$item Table:</p>
<div *ngIf="tables.length > 0">
    <div *ngFor="let table of tables">
        <table border="1" *ngIf="table === '$item'">
            <thead>
                <tr>
                    <th *ngFor="let column of getColumns(table)">{{ column }}</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <tr *ngFor="let row of dataMap[table]">
                    <td *ngFor="let column of getColumns(table)">{{ row[column] }}</td>
                    <td>
                        <button (click)="view${item}(row)" class="btn"><i class="fas fa-eye"></i>View</button>
                        <button (click)="update${item}(row)" class="btn"><i class="fas fa-pencil-alt"></i>Update</button>
                        <button (click)="delete${item}(row._id)" class="btn"><i class="fas fa-trash-alt"></i>delete</button>
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</div>
EOL

    # Create component SCSS file
    cat > "src/app/$item/$item.component.scss" << 'EOL'
table {
    width: 100%;
    border-collapse: collapse;
    min-width: 500px;
    table-layout: auto;
}
th, td {
    padding: 8px;
    text-align: center;
    font-size: 12px;
}
thead {
    background: #014e85;
    color: #fff;
}
tbody tr:nth-child(odd) {
    background: #f9f9f9;
}
tbody tr:nth-child(even) {
    background: #f4f7fa;
}
tbody tr:hover {
    background: #eaf2f8;
}
.btn {
    padding: 8px 12px;
    font-size: 14px;
    background: #d6eaff;
    border: 1px solid #a9d5ff;
    border-radius: 5px;
    cursor: pointer;
}
.btn:hover {
    background: #b8d8ff;
}
@media (max-width: 768px) {
    table {
        min-width: 500px;
    }
}
@media (max-width: 480px) {
    table {
        min-width: 400px;
    }
}
EOL
done

# Create update component files
cat > src/app/update/update.component.ts << 'EOL'
import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { SharedService } from '../services/shared.service';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
    selector: 'app-update',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './update.component.html',
    styleUrls: ['./update.component.scss']
})
export class UpdateComponent implements OnInit {
    table: string = '';
    itemId: string = '';
    itemData: any = {};

    constructor(
        private route: ActivatedRoute,
        private service: SharedService,
        private router: Router
    ) {}

    ngOnInit(): void {
        this.table = this.route.snapshot.paramMap.get('table') || '';
        this.itemId = this.route.snapshot.paramMap.get('id') || '';
        
        if (this.table && this.itemId) {
            this.service.getItemById(this.table, this.itemId).subscribe({
                next: (data: any) => {
                    console.log(`Fetched ${this.table} Data:`, data);
                    if (data) {
                        this.itemData = { ...data };
                    } else {
                        console.warn(`No data found for ${this.table} with ID ${this.itemId}`);
                        alert(`Error: No data found!`);
                    }
                },
                error: (err) => {
                    console.error(`Error fetching ${this.table} data (Table: ${this.table}, ID: ${this.itemId})`, err);
                    alert(`An error occurred while fetching ${this.table} data.`);
                }
            });
        }
    }

    updateItem() {
        this.service.updateItemById(this.table, this.itemId, this.itemData).subscribe({
            next: (response) => {
                console.log("Item updated:", response);
                alert("Item updated");
                this.router.navigate(['/admin']);
            },
            error: (err) => {
                console.error("Erreur update :", err);
                alert("Error while updating");
            }
        });
    }

    objectKeys(obj: any): string[] {
        return obj ? Object.keys(obj) : [];
    }
}
EOL

# Create update component HTML
cat > src/app/update/update.component.html << 'EOL'
<h2>Update {{ table }}</h2>
<form *ngIf="itemData && objectKeys(itemData).length > 0" (ngSubmit)="updateItem()">
    <ng-container *ngFor="let key of objectKeys(itemData)">
        <div *ngIf="key !== '_id'">
            <label>{{ key }}:</label>
            <input type="text" [(ngModel)]="itemData[key]" [name]="key" />
        </div>
    </ng-container>
    <button type="submit">Update</button>
</form>
EOL

# Create update component SCSS
cat > src/app/update/update.component.scss << 'EOL'
/* General form container with sleek design */
form {
    max-width: 600px;
    margin: 40px auto;
    padding: 40px;
    border-radius: 12px;
    background: linear-gradient(135deg, #f5f4f4, #e8eff5);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15);
    font-family: 'Roboto', sans-serif;
    color: #333;
    animation: fadeIn 0.8s ease-out;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
}

@keyframes fadeIn {
    from {
        opacity: 0;
        transform: translateY(-20px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

form:hover {
    transform: translateY(-5px);
    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.2);
}

h2 {
    font-size: 32px;
    font-weight: bold;
    text-align: center;
    color: transparent;
    background: linear-gradient(45deg, #00264d, #008C8C);
    -webkit-background-clip: text;
    background-clip: text;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    margin-bottom: 30px;
    position: relative;
    transition: transform 0.3s ease, color 0.3s ease;
}

h2:hover {
    transform: scale(1.05);
}

form label {
    display: block;
    font-size: 14px;
    font-weight: bold;
    margin-bottom: 8px;
    color: #444;
    text-transform: capitalize;
    letter-spacing: 0.5px;
    transition: color 0.3s ease;
}

form label:hover {
    color: #008C8C;
}

form input {
    width: 100%;
    padding: 12px;
    border: none;
    border-radius: 8px;
    font-size: 16px;
    background: linear-gradient(135deg, #ffffff, #f0f4f8);
    color: #333;
    box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.1);
    transition: box-shadow 0.3s ease, transform 0.3s ease;
}

form input:focus {
    outline: none;
    box-shadow: 0 0 8px rgba(0, 140, 140, 0.5);
    transform: translateY(-2px);
}

form input:hover {
    box-shadow: inset 0 4px 6px rgba(0, 0, 0, 0.1);
}

form button {
    background: linear-gradient(45deg, #012344, #012344);
    color: #fff;
    width: 80%;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: bold;
    margin: 20px auto 0;
    display: block;
    text-transform: uppercase;
    cursor: pointer;
    box-shadow: 0 6px 12px rgba(0, 140, 140, 0.2);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    padding: 10px;
}

form button:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 16px rgba(0, 140, 140, 0.3);
}

form button:active {
    transform: translateY(2px);
    box-shadow: 0 4px 8px rgba(0, 140, 140, 0.2);
}

form div {
    margin-bottom: 20px;
}

@media (max-width: 600px) {
    form {
        padding: 30px;
        margin: 20px;
    }
    form h2 {
        font-size: 28px;
    }
    form button {
        font-size: 16px;
    }
}
EOL

# Create shared service
echo "===== Creating shared service for components ====="
ng g s services/shared

# Create shared service TS
cat > src/app/services/shared.service.ts << 'EOL'
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
    providedIn: 'root'
})
export class SharedService {
    private apiUrl = 'http://localhost:3000/api';

    constructor(private http: HttpClient) {}

    getUsers() {
        return this.http.get(`${this.apiUrl}/getall`);
    }

    getTableData(table: string): Observable<any[]> {
        return this.http.get<any[]>(`${this.apiUrl}/getall/${table}`);
    }

    getItemById(table: string, id: string) {
        return this.http.get(`${this.apiUrl}/${table}/${id}`);
    }

    updateItemById(table: string, id: string, data: any) {
        return this.http.put(`${this.apiUrl}/update/${table}/${id}`, data);
    }

    deleteItem(table: string, id: string) {
        return this.http.delete(`http://localhost:3000/api/delete/${table}/${id}`);
    }

    deleteTable(table: string): Observable<any> {
        return this.http.delete(`${this.apiUrl}/delete/${table}`);
    }
}
EOL

# Create index.html
cat > src/index.html << 'EOL'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>AngularProject</title>
    <base href="/">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/x-icon" href="favicon.ico">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
  </head>
  <body>
    <app-root></app-root>
    <app-admin></app-admin>
    <app-sidebar></app-sidebar>
EOL

# Add dynamic components to index.html
for item in $items; do
    echo "    <app-$item></app-$item>" >> src/index.html
done

# Complete index.html
cat >> src/index.html << 'EOL'
  </body>
</html>
EOL

# Move project to final location
mv "$projectDir" "$FRONTEND_DIR"

echo "===== All components and shared service generated successfully! ====="

# Start the Angular server
echo "Starting the server..."
cd "$FRONTEND_DIR"
ng serve
