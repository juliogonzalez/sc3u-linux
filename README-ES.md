[English version](README.md)

# SimCity 3000 Unlimited nativo para distribuciones GNU/Linux actuales

Este es símplemente el resultado de un [proyecto](https://hackweek.suse.com/16/projects/old-games-on-modern-linux) para la [16 SUSE Hackweek](https://hackweek.suse.com/16/projects).

Dado que ejecutar juegos de Loki u otros juegos nativos antiguos y propietarios puede ser un desafío, decidimos investigar un poco cuánto esfuerzo podría suponer preparar esos juegos para ser ejecutados en una distribuciones GNU/Linux actuales.

## Retos

Para SimCity 3000 los mayores problemas fueron:

- SimCity 3000 es 32 bits
- No funciona con versiones actuales de glib. Esto se puede evitar con las Libererías de [Comptabilidad para Loki](http://www.improbability.net/loki/)
- El parche 2.0 no se puede ejecutar debido a cambios en los estándares POSIX.
- El sonido usa OSS, y no es posible usara padsp, aoss or esdcompact ni con openSUSE 42.3 ni con Debian SID

## Soluciones alternativas.

Hay muchas soluciones alternativas en internet, incluyendo [una](https://www.juliogonzalez.es/como-ejecutar-simcity-3000-en-debian-i386-o-amd64/58) que escribín en castellano hace años, pero al final todas ellas requieren que el usuario ejecute muchos comandos diferentes, con muchos argumentos.

Por lo tanto este repositorio intenta facilitar el procedimiento para que podamos símplemente instalar el juego, aplicar el parche, configurar el sonido y empezar a jugar.

## Instrucciones

### Obtén el juego

Lo primero de todo, necesitas el CD original o una imagen ISO del CD original.

Si no lo tienes prueba una de los siguientes enlaces:

* [Amazon](https://www.amazon.com/s/ref=bl_sr_software?_encoding=UTF8&node=229534&field-brandtextbin=Loki%20Entertainment%20Software)
* [Linux-Discount](http://www.linux-discount.de/software/games/LokiSoft)
* [ixsoft](http://www.ixsoft.de/cgi-bin/web_store.cgi?ref=Catalogs/de/software-games-catalog.html)
* [Linux-Onlineshop](https://www.linux-onlineshop.de/index.php?page=categorie&cat=1&next_page=1) 

### Instalar el juego

Inserta el CD o monta la imagen y usa un terminal para ir al directorio donde el CD/imagen está montada, y ejecuta:

```bash
sudo linux32 ./setup.sh
```

Usa las rutas por defecto para la instalación cuando sean solicitadas, y responde **y** a las diferentes preguntas sobre qué instalar (así no necesitarás el CD o la ISO para jugar).

### Parchea el juego

Clona este repositorio (si estás leyendo esto fichero desde el interfaz web de GitHub), y ve al directorio donde la copia local esté (usando un terminal).

Asegúrate de tener installadas las herramientas requeridas. Los nombres de los paquetes que las proveen depende de tu distribución:

- curl
- cat
- patch
- tar

Ejecuta:

```bash
./sc3u-patcher.sh
```

El script se ocupará de todo, solicitando tu clave para usar sudo cuando sea necesario. Ejecutará el parche oficial 2.0 para Simcity 2.0 (después de parchearlo), así que solo necesitarás seguir el asistente.

En el caso de que no haya errores estarás listo para ejecutar SimCity 3000.

### ¡Pero no tengo sonido!

Si, si estás usando [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) (casi todo el mundo ahora mismo), hay un paso final.

Dado que el juego requiere OSS (hasta el momento no he sido capaz de hacer que funcione con padsp, aoss o esdcompat) necesitarás usar un programa que sea capaz de emular los dispositivos OSS y enviar el audio a PulseAudio.

Necesitarás [osspd](https://sourceforge.net/projects/osspd/).

#### openSUSE/SUSE

Puedes ir a las [descargas de openSUSE](https://software.opensuse.org/download.html?project=home%3Ajuliogonzalez%3Abranches%3Ahome%3Aelvigia&package=ossp) y seleccionar to distribución para una instalación "One Click". Luego puedes añadir tu usuario al grupo de sistema ```audio```, reiniciar tu sesión y deberías ser capaz de ejecutar SimCity 3000 con sonido.

#### Debian/Ubuntu

Install osspd y el backend para PulseAudio:

```bash
apt-get install osspd osspd-pulseaudio
```

#### Arrancando osspd durante los inicios del ordenador

* systemd (openSUSE y Debian actual)

  ```bash
  sudo systemctl enable osspd
  ```

* SysVinit (Debian)

  ```bash
  sudo update-rc.d osspd enable
  ```

### Pantallas panorámicas y altas resoluciones

Por defecto SimCity 3000 solo ofrece unas pocas resoluciones 4:3 al arrancar. El
script auxiliar `sc3u-widescreen.sh` aplica un parche reversible a
`sc3u.dynamic` que:

- evita que `FixStartupResolutionValuesIfNeeded` sustituya las resoluciones de
  arranque no soportadas por un modo 4:3 de reserva;
- hace que `IsStartupResolutionOK` acepte la resolución de arranque solicitada;
- sustituye tres modos 4:3 altos por modos panorámicos: `1152x864` ->
  `1280x720`, `1280x1024` -> `1920x1080` y `1600x1200` -> `2560x1440`.

Ejecútalo después de parchear el juego:

```bash
sudo ./sc3u-widescreen.sh
```

Después inicia el juego y elige la resolución en las opciones de vídeo/pantalla
del juego. Elige solo un modo que tu pantalla soporte de verdad. El ancho y el
alto deben ser divisibles por 8; modos como `1366x768`, `1600x900` y `1440x900`
se sabe que provocan caídas. La interfaz del juego no escala, por lo que se verá
pequeña en pantallas de alta resolución.

El script guarda una copia del binario original en `sc3u.dynamic.orig` la
primera vez que se aplica. Usa:

```bash
./sc3u-widescreen.sh --status
./sc3u-widescreen.sh --revert
```

para comprobar o deshacer el parche. Si el juego está instalado en otro sitio
que no sea `/usr/local/games/SC3U`, indica `--path /ruta/a/SC3U` o define
`SC3U_PATH`.

El parche está basado en
[lfbr0/simcity3000-linux-widescreen-patch](https://github.com/lfbr0/simcity3000-linux-widescreen-patch).
