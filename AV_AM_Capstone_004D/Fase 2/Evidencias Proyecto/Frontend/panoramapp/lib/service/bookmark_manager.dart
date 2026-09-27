import 'package:flutter/foundation.dart';
import 'package:capstone/service/api_event.dart';

// Este manager es un Singleton que nos permite guardar y compartir los eventos 
// favoritos entre distintas pantallas usando un ValueNotifier para actualizar la UI al instante.
class BookmarkManager {
  static final BookmarkManager _instance = BookmarkManager._internal();
  factory BookmarkManager() => _instance;
  BookmarkManager._internal();

  final ValueNotifier<List<ApiEvent>> savedEvents = ValueNotifier([]);

  void toggleBookmark(ApiEvent event) {
    final currentList = List<ApiEvent>.from(savedEvents.value);
    if (isSaved(event)) {
      // Como no hay ID, usamos el nombre y la fecha para identificarlo
      currentList.removeWhere((e) => e.nombre == event.nombre && e.fechaInicio == event.fechaInicio);
    } else {
      currentList.add(event);
    }
    savedEvents.value = currentList;
  }

  bool isSaved(ApiEvent event) {
    return savedEvents.value.any((e) => e.nombre == event.nombre && e.fechaInicio == event.fechaInicio);
  }
}