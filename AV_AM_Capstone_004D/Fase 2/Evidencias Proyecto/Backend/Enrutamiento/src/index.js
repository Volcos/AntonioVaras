import 'dotenv/config';
import Fastify from "fastify";
import statusDB from "./routes/status.js";
import dbConnector from "./plugins/db.js"
import getAllEvents from './routes/getAllEvents.js';

const app = Fastify({
    logger: true
})

const start = async() => {
    try {
        await app.register(dbConnector);
        //await app.register(statusRoute);
        await app.register(statusDB);
        await app.register(getAllEvents);
        
        const PORT = process.env.PORT || 3000;
        await app.listen({ port: PORT, host: '0.0.0.0' });
        
        console.log(`Servidor funcionando en el puerto ${PORT}`);
    
    } catch (err) {
        app.log.error(err);
        process.exit(1);
    }

};

start();