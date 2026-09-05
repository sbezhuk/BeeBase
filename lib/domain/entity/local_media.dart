import 'package:beebase/domain/enum/sync_status.dart';

final class LocalMedia {
  const LocalMedia({
    required this.localId,
    this.serverId,
    required this.ownerType,
    required this.ownerId,
    required this.localFilePath,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    this.syncStatus = SyncStatus.pendingCreate,
    required this.createdAt,
  });

  final String localId;
  final String? serverId;
  final String ownerType;
  final String ownerId;
  final String localFilePath;
  final String originalFilename;
  final String contentType;
  final int sizeBytes;
  final SyncStatus syncStatus;
  final DateTime createdAt;

  LocalMedia copyWith({
    String? localId,
    String? serverId,
    String? ownerType,
    String? ownerId,
    String? localFilePath,
    String? originalFilename,
    String? contentType,
    int? sizeBytes,
    SyncStatus? syncStatus,
    DateTime? createdAt,
  }) {
    return LocalMedia(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      localFilePath: localFilePath ?? this.localFilePath,
      originalFilename: originalFilename ?? this.originalFilename,
      contentType: contentType ?? this.contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'server_id': serverId,
      'owner_type': ownerType,
      'owner_id': ownerId,
      'local_file_path': localFilePath,
      'original_filename': originalFilename,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'sync_status': syncStatus.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LocalMedia.fromMap(Map<String, dynamic> map) {
    return LocalMedia(
      localId: map['local_id'] as String,
      serverId: map['server_id'] as String?,
      ownerType: map['owner_type'] as String,
      ownerId: map['owner_id'] as String,
      localFilePath: map['local_file_path'] as String,
      originalFilename: map['original_filename'] as String,
      contentType: map['content_type'] as String,
      sizeBytes: map['size_bytes'] as int,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == map['sync_status'],
        orElse: () => SyncStatus.pendingCreate,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
