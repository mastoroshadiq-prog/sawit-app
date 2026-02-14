class SopStep {
  final String stepId;
  final String sopId;
  final int stepOrder;
  final String stepTitle;
  final int isRequired;
  final String evidenceType;

  const SopStep({
    required this.stepId,
    required this.sopId,
    required this.stepOrder,
    required this.stepTitle,
    required this.isRequired,
    required this.evidenceType,
  });

  Map<String, dynamic> toMap() {
    return {
      'stepId': stepId,
      'sopId': sopId,
      'stepOrder': stepOrder,
      'stepTitle': stepTitle,
      'isRequired': isRequired,
      'evidenceType': evidenceType,
    };
  }

  factory SopStep.fromMap(Map<String, dynamic> map) {
    return SopStep(
      stepId: (map['stepId'] ?? '').toString(),
      sopId: (map['sopId'] ?? '').toString(),
      stepOrder: (map['stepOrder'] as num?)?.toInt() ?? 0,
      stepTitle: (map['stepTitle'] ?? '').toString(),
      isRequired: (map['isRequired'] as num?)?.toInt() ?? 0,
      evidenceType: (map['evidenceType'] ?? 'none').toString(),
    );
  }
}

