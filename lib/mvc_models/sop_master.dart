class SopMaster {
  final String sopId;
  final String sopCode;
  final String sopName;
  final String sopVersion;
  final int isActive;
  final String taskKeyword;

  const SopMaster({
    required this.sopId,
    required this.sopCode,
    required this.sopName,
    required this.sopVersion,
    required this.isActive,
    required this.taskKeyword,
  });

  Map<String, dynamic> toMap() {
    return {
      'sopId': sopId,
      'sopCode': sopCode,
      'sopName': sopName,
      'sopVersion': sopVersion,
      'isActive': isActive,
      'taskKeyword': taskKeyword,
    };
  }

  factory SopMaster.fromMap(Map<String, dynamic> map) {
    return SopMaster(
      sopId: (map['sopId'] ?? '').toString(),
      sopCode: (map['sopCode'] ?? '').toString(),
      sopName: (map['sopName'] ?? '').toString(),
      sopVersion: (map['sopVersion'] ?? '').toString(),
      isActive: (map['isActive'] as num?)?.toInt() ?? 0,
      taskKeyword: (map['taskKeyword'] ?? '').toString(),
    );
  }
}

