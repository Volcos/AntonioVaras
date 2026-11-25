# Panoramapp

Panoramapp es una aplicación móvil que busca unificar la información sobre distintos eventos en un solo lugar, facilitando información cómo la dirección del evento, las fechas en que se realizará, descripciones del mismo, precios y donde se pueden comprar entradas en caso de ser necesario. De esta manera logramos simplificar el proceso de búsqueda de usuarios que quieran asistir a un evento relacionado a sus intereses, permitiéndoles descubrir panoramas cercanos mediante un mapa interactivo con geolocalización y recibir recordatorios oportunos antes de que comiencen. Además, la plataforma integra un ecosistema híbrido que combina la extracción automatizada desde múltiples fuentes y ticketeras con un portal de autogestión para que organizadores independientes publiquen sus propios eventos, garantizando una cartelera actualizada, centralizada y libre de duplicados.

# Tecnologías

La aplicación fue desarrollada utilizando Android Studio, tomando como base el kit de desarrollo de Flutter para la creación de vistas, la navegación dentro de la página y todas las funcionalidades relacionadas a la lógica del proyecto.
Adicionalmente se hizo uso de la API de OpenStreetMap para la implementación del mapa de la aplicación y el sistema de rutas del mismo.

En cuanto a la capa de negocio de la aplicación, esta se encuentra dividida en dos módulos principales, el primero es el módulo de enrutamiento, en este se encuentra en el entorno de Node.js y utiliza el framework de Fastify para los endpoints que facilitaran la comunicación entre la capa de presentación y la base de datos. El segundo módulo corresponde a la Ingesta, en este se busca la información de los eventos mediante los scrapers desarrollados utilizando la librería de Playwright y los scripts orientados al consumo de API’s. Dicha información es posteriormente estandarizada, para luego pasar por un proceso de validación, ser contrastada con la información ya existente en la base de datos, para finalmente ser insertada en caso de no coincidir con ningún registro ya existente.
La capa de negocio se encuentra desplegada y funcionando en el ecosistema en la nube de Google Cloud Platform utilizando los servicios de Cloud Run para mantener activo y accesible el módulo de enrutamiento y activar el módulo de ingesta en una hora programada con el servicio de Cloud Scheduler de la misma plataforma.

Para el despliegue de la base de datos utilizamos Neon.tech, el cuál es un ecosistema en la nube que permite administrar la base de datos y mantenerla activa en todo momento. La base de datos está hecha en PostgreSQL y utiliza su extensión PostGIS para realizar consultas que utilicen información geográfica para obtener sus resultados.

# Instrucciones para el despliegue
Comenzando desde el backend, en caso de querer utilizar únicamente Node.js para la ejecución primero se debe ir a la carpeta Ingesta o Enrutamiento en la cuál se debe abrir una terminal donde, en caso de ser la primera vez que se ejecuta, se debe utilizar el comando “npm install” para instalar las dependencias que se utilizan en el módulo. Una vez instaladas las dependencias se debe usar el comando “node src/index.js” para ejecutar el módulo, el mismo proceso se debe realizar en ambos módulos.
Si se quiere utilizar Docker para arrancar el módulo es necesario contar con la aplicación Docker Desktop la cuál debe estar funcionando mientras se ejecuta cualquiera de los módulos. Con Docker Desktop funcionando, se debe abrir una terminal dentro de la carpeta Ingesta o Enrutamiento y ejecutar los comandos “docker compose build” seguido de “docker compose up” con lo cual ya se encontrará el módulo funcionando.

# Metodología 
Para el proyecto utilizamos una metodología en cascada dividida en 4 fases que abarcan la planificación del proyecto donde se tomaron requerimientos, se creo el cronograma y se identificaron posibles riesgos que se podrían presentar durante el desarrollo.
En la fase de diseño se comenzó con el diseño de la solución, donde se realizó la arquitectura del proyecto, el modelo de datos del mismo y los mockups de cómo debería ser la aplicación final.
Durante la fase de desarrollo se comenzó a construir la solución diseñada en la fase anterior, donde se realizó tanto el apartado visual de la aplicación cómo las funcionalidades del mismo.
En la última fase se pone a prueba el producto desarrollado en la fase anterior, buscando posibles errores que pudieran existir, comportamientos inesperados de la aplicación, respuestas lentas y otros contratiempos que puedan comprometer la calidad del proyecto.

# Integrantes

| Responsable| Rol | Responsabilidades |
| :--- | :--- | :--- |
| Benjamín Díaz | Gerente de Proyecto | Encargado de la documentación del proyecto, <br>dirigir al equipo y cuidar los tiempos del proyecto |
|Iñaki Fernández| Desarrollador principal | Encargado principal de desarrollar la aplicación, <br>investigar herramientas y tecnologías que ayuden al desarrollo del proyecto.
|Benjamín Vargas| Desarrollador | Apoyo del desarrollador principal y encargado del manejo de datos.| 

# Arquitectura 
<img width="1357" height="712" alt="ArquitecturaPanoramapp" src="https://github.com/user-attachments/assets/3b6ec0cc-14e5-4815-98c3-cb0fc99fc461" />
