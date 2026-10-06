import 'dotenv/config';
import Fastify from "fastify";
import statusDB from "./routes/status.js";
import dbConnector from "./plugins/db.js"
import eventos from './routes/getAllEvents.js';

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

        
        const PORT = process.env.PORT || 3000;
        await app.listen({ port: PORT, host: '0.0.0.0' });
        
        console.log(`Servidor funcionando en el puerto ${PORT}`);
    
    } catch (err) {
        app.log.error(err);
        process.exit(1);
    }

};

start();