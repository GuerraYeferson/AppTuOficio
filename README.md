# TuOficio

Aplicación móvil que conecta clientes con trabajadores de oficios
(carpintería, pintura, cerrajería, gasfitería, etc.).

> Estado: MVP académico en desarrollo.

## Funcionalidades del MVP

- Registro, inicio y cierre de sesión (cliente y trabajador)
- Perfil obligatorio y editable para cada rol
- Cliente: CRUD de anuncios
- Trabajador: perfil con oficios (selección múltiple) y disponibilidad
- Eliminación de cuenta

## Tecnologías

| Parte | Tecnología |
|---|---|
| App móvil | Flutter / Dart |
| API | Laravel + Sanctum |
| Base de datos | MySQL |

## Estructura

```
TuOficio/
├── backend/   API en Laravel
└── app/       App en Flutter
```

## Cómo ejecutarlo

### Backend

```bash
cd backend
composer install
copy .env.example .env
php artisan key:generate
# Configura DB_DATABASE, DB_USERNAME y DB_PASSWORD en .env
php artisan migrate --seed
php artisan serve --host=0.0.0.0
```

### App

```bash
cd app
flutter pub get
# Edita lib/config/api_config.dart con la IP de tu PC
flutter run
```