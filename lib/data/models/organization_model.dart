class OrganizationModel {
  final String orgId;
  final String name;
  final String country;
  final String countryCode;
  final String currency;
  final String currencySymbol;
  final String timeZone;
  final List<int> workingDays;
  final double standardWorkHours;
  final String salaryBasis;
  final double overtimeMultiplier;
  final String status;
  final String? adminEmail;
  final String? ownerUid;
  final String? businessType;

  const OrganizationModel({
    required this.orgId,
    required this.name,
    this.country = 'IN',
    this.countryCode = '+91',
    this.currency = 'INR',
    this.currencySymbol = '₹',
    this.timeZone = 'Asia/Kolkata',
    this.workingDays = const [1, 2, 3, 4, 5, 6],
    this.standardWorkHours = 8.0,
    this.salaryBasis = 'monthly_26',
    this.overtimeMultiplier = 1.5,
    this.status = 'active',
    this.adminEmail,
    this.ownerUid,
    this.businessType,
  });

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';

  factory OrganizationModel.fromMap(Map<String, dynamic> map, String id) {
    final rawWorkingDays = map['workingDays'];
    List<int> parsedDays = [1, 2, 3, 4, 5, 6];
    if (rawWorkingDays is List) {
      parsedDays = rawWorkingDays.map((e) => (e as num).toInt()).toList();
    }

    return OrganizationModel(
      orgId: id,
      name: map['name'] as String? ?? id,
      country: map['country'] as String? ?? 'IN',
      countryCode: map['countryCode'] as String? ?? '+91',
      currency: map['currency'] as String? ?? 'INR',
      currencySymbol: map['currencySymbol'] as String? ?? '₹',
      timeZone: map['timeZone'] as String? ?? 'Asia/Kolkata',
      workingDays: parsedDays,
      standardWorkHours: (map['standardWorkHours'] as num?)?.toDouble() ?? 8.0,
      salaryBasis: map['salaryBasis'] as String? ?? 'monthly_26',
      overtimeMultiplier: (map['overtimeMultiplier'] as num?)?.toDouble() ?? 1.5,
      status: map['status'] as String? ?? 'active',
      adminEmail: map['adminEmail'] as String?,
      ownerUid: map['ownerUid'] as String?,
      businessType: map['businessType'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'name': name,
      'country': country,
      'countryCode': countryCode,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'timeZone': timeZone,
      'workingDays': workingDays,
      'standardWorkHours': standardWorkHours,
      'salaryBasis': salaryBasis,
      'overtimeMultiplier': overtimeMultiplier,
      'status': status,
      'adminEmail': adminEmail,
      'ownerUid': ownerUid,
      'businessType': businessType,
    };
  }
}

