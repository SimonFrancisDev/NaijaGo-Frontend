class Address {
  final String id;
  final String name;
  final String phoneNumber;
  final String addressLine;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final String? apartmentNumber;
  final bool isDefault;

  Address({
    this.id = '',
    required this.name,
    required this.phoneNumber,
    required this.addressLine,
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.country = '',
    this.apartmentNumber,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      addressLine: json['addressLine'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zipCode'] ?? '',
      country: json['country'] ?? '',
      apartmentNumber: json['apartmentNumber'],
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'addressLine': addressLine,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
      'apartmentNumber': apartmentNumber,
      'isDefault': isDefault,
    };
  }

  String get fullAddress {
    final apt = apartmentNumber != null && apartmentNumber!.isNotEmpty
        ? 'Apt $apartmentNumber, '
        : '';
    return '$apt$addressLine, $city, $state, $zipCode, $country';
  }

  String get postalCode => zipCode;
}