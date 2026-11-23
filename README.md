# SADM

Aplicación web y móvil desarrollada con Flutter.

## Desplegar la aplicación web en Vercel

El repositorio incluye `vercel.json` y `scripts/vercel-build.sh`. Vercel instala
Flutter 3.47.5, compila la aplicación web y publica `build/web`.

### Antes de desplegar

- El backend debe estar desplegado en una URL pública con HTTPS. No uses
  `localhost`, porque en producción apuntaría al dispositivo de cada visitante.
- Configura el backend para permitir solicitudes CORS desde el dominio de
  Vercel que usarás, incluidos los dominios de Preview si los necesitas.
- La URL base debe incluir el contexto de la API, por ejemplo
  `https://api.ejemplo.com/SADM/api`, sin una barra final.

### Pasos

1. Sube este proyecto a un repositorio de GitHub.
2. Entra en [Vercel](https://vercel.com), selecciona **Add New → Project** e
   importa el repositorio.
3. Deja **Root Directory** en la raíz del repositorio. Vercel leerá
   `vercel.json`; la salida estática configurada es `build/web`.
4. En **Settings → Environment Variables**, agrega:
   - **Name:** `API_BASE_URL`
   - **Value:** la URL HTTPS completa de la API, por ejemplo
     `https://api.ejemplo.com/SADM/api`
   - Selecciona los entornos que usarás (**Production**, y también **Preview**
     si corresponde).
5. Guarda la variable y pulsa **Deploy**. Si cambias la variable después,
   vuelve a desplegar para que Flutter la incorpore en la compilación.
6. Cuando termine, abre el dominio asignado por Vercel y comprueba el inicio de
   sesión y las funciones que consumen el backend. Si el navegador bloquea las
   solicitudes, revisa HTTPS y CORS en el backend.

`API_BASE_URL` se incorpora al código web durante la compilación y será visible
para los usuarios; úsala solo para la URL pública del API, nunca para secretos.
En ejecución local, si no se define, la aplicación conserva sus direcciones
predeterminadas (`localhost` y `10.0.2.2`).

### Compilación web local

Con Flutter instalado, ejecuta:

```bash
flutter pub get
flutter build web --release --base-href /
```

El resultado queda en `build/web`.
