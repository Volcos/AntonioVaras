import 'dotenv/config';
import Fastify from "fastify";
import statusDB from "./App/status.js";
import dbConnector from "./plugins/db.js"
import eventos from './App/getAllEvents.js';
import crearEvento from './App/createEvent.js'
import crearUsuario from './User/createUser.js'
import eliminarUsuario from './User/deleteUser.js'
import obtenerUsuarioPorId from './User/getUserById.js'
import logUser from './User/logUser.js'

const app = Fastify({
    logger: true
})

const start = async() => {
    try {
        await app.register(dbConnector);
        await app.register(statusDB);
        // ej: /status/
        await app.register(eventos);
        // ej: /eventos/cercanos?lat=-33.43&lng=-70.65
        await app.register(crearEvento);
        
        await app.register(crearUsuario);
        await app.register(eliminarUsuario);
        await app.register(obtenerUsuarioPorId);

        await app.register(logUser);    

        const PORT = process.env.PORT || 3000;
        await app.listen({ port: PORT, host: '0.0.0.0' });
        
        console.log(`Servidor funcionando en el puerto ${PORT}`);
    
    } catch (err) {
        app.log.error(err);
        process.exit(1);
    }

};

start();