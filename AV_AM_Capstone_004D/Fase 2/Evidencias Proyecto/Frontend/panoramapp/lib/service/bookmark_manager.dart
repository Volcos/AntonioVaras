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
      currentList.removeWhere((savedEvent) => _sameEvent(savedEvent, event));
    } else {
      currentList.add(event);
    }
    savedEvents.value = currentList;
  }

  bool isSaved(ApiEvent event) {
    return savedEvents.value.any((savedEvent) => _sameEvent(savedEvent, event));
  }

  bool _sameEvent(ApiEvent first, ApiEvent second) {
    if (first.id != null &&
        first.id!.isNotEmpty &&
        second.id != null &&
        second.id!.isNotEmpty) {
      return first.id == second.id;
    }

    return first.nombre == second.nombre &&
        first.fechaInicio == second.fechaInicio;
  }
}
