class ApiEvent {
  String nombre;
  String descripcion;
  String fechaInicio;
  String fechaTermino;
  String hora;
  String localizacion;
  String imagen;
  String fuenteInfo;
  String organizador;

  ApiEvent({
    required this.nombre,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaTermino,
    required this.hora,
    required this.localizacion,
    required this.imagen,
    required this.fuenteInfo,
    required this.organizador,
  });

  static ApiEvent objJson(Map<String, dynamic> json) {
    return ApiEvent(
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      fechaInicio: json['fecha_inicio'] ?? json['fechaInicio'] ?? '',
      fechaTermino: json['fecha_termino'] ?? json['fechaTermino'] ?? '',
      hora: json['hora'] ?? '',
      localizacion: json['localizacion'] ?? '',
      imagen: json['imagen'] ?? '',
      fuenteInfo: json['fuente_info'] ?? json['fuenteInfo'] ?? '',
      organizador: json['organizador'] ?? '',
    );
  }
}
