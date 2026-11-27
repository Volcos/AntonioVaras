import 'package:flutter/foundation.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/apibenja_service.dart';
import 'package:capstone/service/auth_service.dart';
import 'package:capstone/service/notification_service.dart';
import 'package:capstone/service/push_notification_service.dart';

class BookmarkToggleResult {
  final bool saved;
  final bool reminderEnabled;
  final bool reminderUnavailable;

  const BookmarkToggleResult({
    required this.saved,
    required this.reminderEnabled,
    required this.reminderUnavailable,
  });
}

// Este manager es un Singleton que nos permite guardar y compartir los eventos
// favoritos entre distintas pantallas usando un ValueNotifier para actualizar la UI al instante.
class BookmarkManager {
  static final BookmarkManager _instance = BookmarkManager._internal();
  factory BookmarkManager() => _instance;
  BookmarkManager._internal();

  final ValueNotifier<List<ApiEvent>> savedEvents = ValueNotifier([]);

  Future<BookmarkToggleResult> toggleBookmark(ApiEvent event) async {
    final wasSaved = isSaved(event);
    final shouldSave = !wasSaved;
    final token = await AuthService.getToken();
    final hasSession = token != null && token.isNotEmpty;
    if (hasSession && event.fechaIds.isEmpty) {
      try {
        final resolvedDateIds = await ApibenjaService.getEventDateIds(event);
        event.fechaIds.addAll(
          resolvedDateIds.where((id) => !event.fechaIds.contains(id)),
        );
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'event reminders',
            context: ErrorDescription(
              'while loading the API event dates before saving',
            ),
          ),
        );
      }
    }
    final fechaIds = event.fechaIds;
    final canRegisterReminder = hasSession && fechaIds.isNotEmpty;

    if (canRegisterReminder) {
      for (final fechaId in fechaIds) {
        await PushNotificationService.toggleReminder(
          jwtToken: token,
          fechaId: fechaId,
          activar: shouldSave,
        );
      }
    }

    final currentList = List<ApiEvent>.from(savedEvents.value);
    if (wasSaved) {
      currentList.removeWhere((savedEvent) => _sameEvent(savedEvent, event));
    } else {
      currentList.add(event);
    }
    savedEvents.value = currentList;

    try {
      if (shouldSave && !canRegisterReminder) {
        await NotificationService().scheduleSavedEventUpcomingNotification(
          event: event,
        );
      } else {
        await NotificationService().cancelSavedEventNotification(event);
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'event bookmarks',
          context: ErrorDescription(
            'while updating the local notification for a saved event',
          ),
        ),
      );
    }

    return BookmarkToggleResult(
      saved: shouldSave,
      reminderEnabled: canRegisterReminder && shouldSave,
      reminderUnavailable: hasSession && !canRegisterReminder,
    );
  }

  void removeIfSaved(ApiEvent event) {
    final currentList = List<ApiEvent>.from(savedEvents.value);
    final initialLength = currentList.length;
    currentList.removeWhere((savedEvent) => _sameEvent(savedEvent, event));
    if (currentList.length != initialLength) {
      savedEvents.value = currentList;
      NotificationService().cancelSavedEventNotification(event).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'event bookmarks',
            context: ErrorDescription(
              'while cancelling a removed event notification',
            ),
          ),
        );
      });
    }
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
