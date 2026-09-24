import '../models/event.dart';

final List<Event> mockEvents = [
  Event(
    id: '1',
    title: 'Deep Purple',
    imageUrl: 'https://images.unsplash.com/photo-1549834125-82d3c48159a3?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80', // Replace with a generic rock band/concert image
    description: 'La legendaria banda Deep Purple regresa a Chile para presentarse en el Movistar Arena este 8 de diciembre a las 20:00 hrs. Vive una noche histórica junto a uno de los pilares del rock mundial, interpretando clásicos inolvidables que han marcado generaciones. Un concierto imperdible para los amantes del rock en vivo en Santiago. Asegura tu entrada ahora en Punto Ticket.',
    dateInfo: '8 de diciembre, 20:00 hrs',
  ),
  Event(
    id: '2',
    title: 'Minecraft Experience',
    imageUrl: 'https://images.unsplash.com/photo-1607513746994-51f730a44832?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    description: 'Una misión en el mundo real. Moonlight Trail.',
    dateInfo: 'Varios horarios',
  ),
  Event(
    id: '3',
    title: 'Hello world! AWS',
    imageUrl: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    description: 'Despegando tu primera landing page en AWS. Presencial, Jueves 03, Septiembre.',
    dateInfo: 'Jueves 3 Septiembre, 11 AM',
  ),
];
