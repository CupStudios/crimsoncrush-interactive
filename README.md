# 🩸 Crimson Crush: Interactive

¡Bienvenido al repositorio oficial de **Crimson Crush: Interactive**! Este es un proyecto de videojuego interactivo en 2D desarrollado utilizando el motor gráfico **LÖVE (Love2D)** y programado completamente en **Lua**. El juego cuenta con mecánicas dinámicas de combate, un sistema de gestión de entidades optimizado, controles móviles en pantalla y un actualizador automático multiplataforma conectado a GitHub.

---

## 🚀 Características Principales

* **Motor LÖVE (Love2D):** Aprovechamiento de la velocidad de LuaJIT para físicas y renderizado fluidos a 12/60 FPS.
* **Virtual Screen System:** Sistema de resolución virtual adaptativa que mantiene la relación de aspecto perfecta en cualquier pantalla (PC y dispositivos móviles Android).
* **Combate Dinámico:** Control de habilidades, ataques básicos (M1), ráfagas de área (AoE Blast) y recolección de orbes (*Will Orbs*).
* **Controles Híbridos:** Soporte completo para teclado/mouse en PC y palancas de control virtuales (*Mobile Joysticks*) integradas de forma nativa para Android.
* **Actualizador Automático (Auto-Updater):** Módulo inteligente que comprueba la versión contra el repositorio de GitHub y descarga/aplica parches en caliente (Hot-Reloading) sin congelar la interfaz de usuario.

---

## 🎮 Controles del Juego

El juego detecta automáticamente la plataforma y adapta la distribución de controles.

### 💻 En Computadora (PC / Linux / macOS)
* **Movimiento:** Teclas `W`, `A`, `S`, `D` o Flechas de dirección.
* **Ataque Básico (M1):** Clic Izquierdo del mouse.
* **Habilidad Especial (AoE Blast):** Tecla `Espacio` o `E`.
* **Sistema de Actualizaciones:**
    * `U` - Descargar actualización (cuando esté disponible).
    * `Enter` - Aplicar actualización descargada y reiniciar el juego.

### 📱 En Dispositivos Móviles (Android)
* **Movimiento:** Joystick virtual ubicado en la esquina inferior izquierda de la pantalla.
* **Ataques y Habilidades:** Botones táctiles virtuales ubicados en la esquina inferior derecha.

---

## 🛠️ Estructura del Proyecto

El código está organizado de manera modular para facilitar su mantenimiento y escalabilidad:

```text
├── Assets/              # Recursos multimedia (Imágenes, Sprites, Audio, Fuentes)
├── Core/                # Sistemas base del motor (Cámara, Virtual Screen)
├── Data/                # Archivos de configuración y bases de datos JSON (Efectos, Guardados)
├── Entities/            # Lógica de objetos (Player, Projectile, AoE Blast, Dummies)
├── Utils/               # Helpers y módulos complementarios (Collision, Mobile Controls, Updater)
├── Wills/               # Mecánicas de almas/habilidades específicas del Lore
├── json.lua             # Librería de decodificación para persistencia de datos
└── main.lua             # Punto de entrada principal del ciclo de vida de LÖVE

```

---

## 📦 Instalación y Ejecución

### Requisitos Previos

Necesitas tener instalado **LÖVE** (versión 11.0 o superior recomendada) en tu sistema. Puedes descargarlo desde [love2d.org](https://love2d.org/).

### Ejecución en PC (Linux / Windows)

1. Clona este repositorio en tu máquina local:
```bash
git clone [https://github.com/cupstudios/crimsoncrush-interactive.git](https://github.com/cupstudios/crimsoncrush-interactive.git)

```


2. Entra al directorio del proyecto:
```bash
cd crimsoncrush-interactive

```


3. Ejecuta el juego usando LÖVE:
```bash
love .

```


*(En Linux también puedes arrastrar la carpeta directamente hacia la ventana de LÖVE o la terminal).*

### Compilación para Android

El proyecto incluye soporte nativo para resoluciones móviles. Para empaquetarlo en un archivo ejecutable `.apk`, se recomienda utilizar la herramienta oficial `love-android-compilation` o mapear el directorio como un archivo `.love` comprimido en formato ZIP dentro del almacenamiento de la aplicación LÖVE en Android.

---

## 🔄 Sistema de Actualización Automática

El juego incluye un gestor en `Utils/updater.lua` que se comunica de forma asíncrona mediante hilos (`love.thread`) con este repositorio.

### Cómo publicar una nueva actualización:

1. Incrementa el número de versión en el archivo `version.json` de la rama principal (`main`).
2. Genera el archivo empaquetado del juego (`game.love`).
3. Sube el archivo `.love` a la sección de **Releases** de GitHub como un asset público.
4. Actualiza el campo `"download_url"` en tu `version.json` apuntando directamente al enlace de descarga del asset de la Release.

---

## 📝 Créditos y Contribuciones

Desarrollado con pasión por **CupStudios**. Historias, Lore y mecánicas inspiradas en el universo de *Crimson Crush*.

Si deseas contribuir al diseño de personajes, balance de habilidades o optimización del motor:

1. Haz un **Fork** del proyecto.
2. Crea una rama con tu nueva característica (`git checkout -b feature/NuevaMecanica`).
3. Haz un **Commit** de tus cambios (`git commit -m 'Añadida nueva habilidad'`).
4. Sube la rama (`git push origin feature/NuevaMecanica`).
5. Abre un **Pull Request** para revisión.
