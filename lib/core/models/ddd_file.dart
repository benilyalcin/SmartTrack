class DddFile {
  final String id;
  final DateTime downloadedAt;

  final String cardType;

  final String cardHolderName;
  final int fileSizeBytes;

  final bool isSimulated;

  final String downloadKind;

  final String localPath;
  final String? webBytesBase64;

  final String secondaryLocalPath;
  final String? secondaryWebBytesBase64;

  final bool isTrashed;
  final DateTime? trashedAt;

  const DddFile({
    required this.id,
    required this.downloadedAt,
    required this.cardType,
    required this.cardHolderName,
    required this.fileSizeBytes,
    required this.isSimulated,
    this.downloadKind = 'card',
    this.localPath = '',
    this.webBytesBase64,
    this.secondaryLocalPath = '',
    this.secondaryWebBytesBase64,
    this.isTrashed = false,
    this.trashedAt,
  });

  DddFile copyWith({bool? isTrashed, DateTime? trashedAt}) {
    return DddFile(
      id: id,
      downloadedAt: downloadedAt,
      cardType: cardType,
      cardHolderName: cardHolderName,
      fileSizeBytes: fileSizeBytes,
      isSimulated: isSimulated,
      downloadKind: downloadKind,
      localPath: localPath,
      webBytesBase64: webBytesBase64,
      secondaryLocalPath: secondaryLocalPath,
      secondaryWebBytesBase64: secondaryWebBytesBase64,
      isTrashed: isTrashed ?? this.isTrashed,
      trashedAt: trashedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'downloadedAt': downloadedAt.toIso8601String(),
    'cardType': cardType,
    'cardHolderName': cardHolderName,
    'fileSizeBytes': fileSizeBytes,
    'isSimulated': isSimulated,
    'downloadKind': downloadKind,
    'localPath': localPath,
    'webBytesBase64': webBytesBase64,
    'secondaryLocalPath': secondaryLocalPath,
    'secondaryWebBytesBase64': secondaryWebBytesBase64,
    'isTrashed': isTrashed,
    'trashedAt': trashedAt?.toIso8601String(),
  };

  factory DddFile.fromJson(Map<String, dynamic> json) => DddFile(
    id: json['id'] as String,
    downloadedAt: DateTime.parse(json['downloadedAt'] as String),
    cardType: json['cardType'] as String,
    cardHolderName: json['cardHolderName'] as String? ?? '',
    fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
    isSimulated: json['isSimulated'] as bool? ?? false,
    downloadKind: json['downloadKind'] as String? ?? 'card',
    localPath: json['localPath'] as String? ?? '',
    webBytesBase64: json['webBytesBase64'] as String?,
    secondaryLocalPath: json['secondaryLocalPath'] as String? ?? '',
    secondaryWebBytesBase64: json['secondaryWebBytesBase64'] as String?,
    isTrashed: json['isTrashed'] as bool? ?? false,
    trashedAt: json['trashedAt'] != null
        ? DateTime.parse(json['trashedAt'] as String)
        : null,
  );
}
