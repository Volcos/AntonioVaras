import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:capstone/service/auth_service.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/create_event_service.dart';
import 'package:capstone/service/web_service.dart';
import 'package:capstone/service/bookmark_manager.dart';
import 'package:capstone/views/create_event.dart';
import 'package:capstone/views/event_detail_screen.dart';
import 'package:capstone/views/login_view.dart';
import 'package:capstone/service/notification_service.dart';
import 'package:capstone/service/push_notification_service.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  AuthUser? _user;
  bool _loading = true;
  List<ApiEvent> _managedEvents = [];
  bool _loadingEvents = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getSavedUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
    await _loadManagedEvents(user);
  }

  Future<void> _loadManagedEvents(AuthUser? user) async {
    if (user == null || (user.userType != 1 && user.userType != 3)) {
      return;
    }
    if (!mounted) return;
    setState(() => _loadingEvents = true);
    try {
      final events = await Webservice.getEvents(forceRefresh: true);
      if (!mounted) return;
      final managed = user.userType == 1
          ? events
          : events.where((event) {
              final creatorMatches =
                  event.creatorId != null &&
                  event.creatorId!.trim().isNotEmpty &&
                  event.creatorId!.trim() == user.id.trim();
              final organizerMatches =
                  event.organizador.trim().toLowerCase() ==
                  user.name.trim().toLowerCase();
              return creatorMatches || organizerMatches;
            }).toList();
      setState(() {
        _managedEvents = managed;
        _loadingEvents = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  String get _userTypeLabel {
    switch (_user?.userType) {
      case 1:
        return 'Administrador';
      case 2:
        return 'Cliente';
      case 3:
        return 'Organizador';
      default:
        return _user == null ? 'Invitado' : 'Usuario';
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Quieres cerrar la sesión actual?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.pinkAccent),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        await PushNotificationService.unregisterDevice(token);
      }
      await AuthService.logout();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo desvincular el dispositivo. '
            'La sesión sigue activa: $error',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.pinkAccent),
        ),
      );
    }

    final user = _user;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
          children: [
            const Text(
              'Perfil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF202020),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFF263238)],
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.person_fill,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user == null
                        ? 'Invitado'
                        : (user.name.isNotEmpty ? user.name : 'Usuario'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _userTypeLabel,
                    style: const TextStyle(
                      color: Colors.pinkAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user?.email.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Text(
                      user!.email,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  if (user?.rut.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      'RUT ${user!.rut}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  if (user?.id.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      'ID ${user!.id}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_user?.userType == 1 || _user?.userType == 3)
              _profileButton(
                icon: CupertinoIcons.add_circled,
                title: 'Crear evento',
                subtitle: 'Publicar una nueva experiencia',
                onTap: () async {
                  await Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const CreateEventView()),
                  );
                  await _loadManagedEvents(_user);
                },
              ),
            if (_user?.userType == 1 || _user?.userType == 3) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _user?.userType == 1
                          ? 'Administrar eventos'
                          : 'Mis eventos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _loadManagedEvents(_user),
                    icon: const Icon(
                      CupertinoIcons.refresh,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loadingEvents)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.pinkAccent,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_managedEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No tienes eventos publicados.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                ..._managedEvents.map((event) => _managedEventCard(event)),
            ],
            const SizedBox(height: 12),
            _profileButton(
              icon: CupertinoIcons.gear,
              title: 'Ajustes',
              subtitle: 'Configuración de la cuenta',
              onTap: () => _showSettings(),
            ),
            const SizedBox(height: 12),
            if (user == null)
              _profileButton(
                icon: CupertinoIcons.person_badge_plus,
                title: 'Iniciar sesión',
                subtitle: 'Accede con tu cuenta',
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (_) => const LoginView()),
                    (_) => false,
                  );
                },
              )
            else
              _profileButton(
                icon: CupertinoIcons.square_arrow_right,
                title: 'Cerrar sesión',
                subtitle: 'Salir de PanoramAPP',
                onTap: _logout,
                destructive: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _managedEventCard(ApiEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => EventDetailScreen(event: event),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.hasMultipleSchedules
                        ? 'Múltiples fechas'
                        : event.displayDate,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: () async {
              await Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => CreateEventView(eventToEdit: event),
                ),
              );
              await _loadManagedEvents(_user);
            },
            icon: const Icon(CupertinoIcons.pencil, color: Colors.amberAccent),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () => _confirmDeleteEvent(event),
            icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteEvent(ApiEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text(
          'Eliminar evento',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Quieres eliminar "${event.nombre}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión nuevamente.')),
      );
      return;
    }

    try {
      await CreateEventService.deleteEvent(
        eventId: event.id ?? '',
        token: token,
      );
      Webservice.removeEventFromCache(event.id);
      BookmarkManager().removeIfSaved(event);
      await Webservice.refreshEvents();
      await _loadManagedEvents(_user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento eliminado correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ajustes y Notificaciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      CupertinoIcons.person,
                      color: _user == null ? Colors.white54 : Colors.pinkAccent,
                    ),
                    title: Text(
                      _user == null
                          ? 'Sesión de invitado'
                          : 'Cuenta: ${_user!.name}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  const Text(
                    'Configuración de Notificaciones',
                    style: TextStyle(
                      color: Colors.pinkAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Activar Notificaciones',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Habilitar o desactivar todas las alertas',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    value: NotificationService().notificationsEnabled,
                    activeColor: Colors.pinkAccent,
                    onChanged: (val) async {
                      await NotificationService().setNotificationsEnabled(val);
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  if (NotificationService().notificationsEnabled) ...[
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Nuevos Panoramas',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Notificar al agregarse un evento nuevo',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      value:
                          NotificationService().newEventsNotificationsEnabled,
                      activeColor: Colors.pinkAccent,
                      onChanged: (val) async {
                        await NotificationService()
                            .setNewEventsNotificationsEnabled(val);
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Eventos Cercanos',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Notificar cuando haya un evento cerca de ti',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      value: NotificationService().nearbyNotificationsEnabled,
                      activeColor: Colors.pinkAccent,
                      onChanged: (val) async {
                        await NotificationService()
                            .setNearbyNotificationsEnabled(val);
                        setModalState(() {});
                      },
                    ),
                    if (NotificationService().nearbyNotificationsEnabled) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Rango de distancia cercana',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${NotificationService().nearbyRadiusKm.toStringAsFixed(0)} km',
                            style: const TextStyle(
                              color: Colors.pinkAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: NotificationService().nearbyRadiusKm,
                        min: 1.0,
                        max: 50.0,
                        divisions: 49,
                        activeColor: Colors.pinkAccent,
                        inactiveColor: Colors.white24,
                        label:
                            '${NotificationService().nearbyRadiusKm.toStringAsFixed(0)} km',
                        onChanged: (val) async {
                          await NotificationService().setNearbyRadiusKm(val);
                          setModalState(() {});
                        },
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Recordatorios de Favoritos',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Avisar antes de iniciar tus eventos guardados',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      value:
                          NotificationService().savedEventsNotificationsEnabled,
                      activeColor: Colors.pinkAccent,
                      onChanged: (val) async {
                        await NotificationService()
                            .setSavedEventsNotificationsEnabled(val);
                        setModalState(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return Material(
      color: const Color(0xFF202020),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: destructive
                      ? const Color(0x33FF5252)
                      : const Color(0x33E91E63),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: destructive ? Colors.redAccent : Colors.pinkAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white38,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
