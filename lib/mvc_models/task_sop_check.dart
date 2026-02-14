class TaskSopCheck {
  final String checkId;
  final String executionId;
  final String assignmentId;
  final String spkNumber;
  final String sopId;
  final String stepId;
  final int isChecked;
  final String note;
  final String? evidencePath;
  final String checkedAt;
  final int flag;

  const TaskSopCheck({
    required this.checkId,
    required this.executionId,
    required this.assignmentId,
    required this.spkNumber,
    required this.sopId,
    required this.stepId,
    required this.isChecked,
    required this.note,
    required this.evidencePath,
    required this.checkedAt,
    required this.flag,
  });

  Map<String, dynamic> toMap() {
    return {
      'checkId': checkId,
      'executionId': executionId,
      'assignmentId': assignmentId,
      'spkNumber': spkNumber,
      'sopId': sopId,
      'stepId': stepId,
      'isChecked': isChecked,
      'note': note,
      'evidencePath': evidencePath,
      'checkedAt': checkedAt,
      'flag': flag,
    };
  }

  factory TaskSopCheck.fromMap(Map<String, dynamic> map) {
    return TaskSopCheck(
      checkId: (map['checkId'] ?? '').toString(),
      executionId: (map['executionId'] ?? '').toString(),
      assignmentId: (map['assignmentId'] ?? '').toString(),
      spkNumber: (map['spkNumber'] ?? '').toString(),
      sopId: (map['sopId'] ?? '').toString(),
      stepId: (map['stepId'] ?? '').toString(),
      isChecked: (map['isChecked'] as num?)?.toInt() ?? 0,
      note: (map['note'] ?? '').toString(),
      evidencePath: map['evidencePath']?.toString(),
      checkedAt: (map['checkedAt'] ?? '').toString(),
      flag: (map['flag'] as num?)?.toInt() ?? 0,
    );
  }
}

