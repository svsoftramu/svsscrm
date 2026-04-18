class Lead {
  final String? id;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phoneNumber;
  final String? company;
  final String? title;
  final String? status;
  final String? leadStatus;
  final String? source;
  final String? leadValue;
  final String? website;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? zip;
  final String? description;
  final String? dateAdded;
  final String? hash;
  final String? addedFrom;
  final String? leadOrder;

  Lead({
    this.id,
    this.name,
    this.firstName,
    this.lastName,
    this.email,
    this.phoneNumber,
    this.company,
    this.title,
    this.status,
    this.leadStatus,
    this.source,
    this.leadValue,
    this.website,
    this.address,
    this.city,
    this.state,
    this.country,
    this.zip,
    this.description,
    this.dateAdded,
    this.hash,
    this.addedFrom,
    this.leadOrder,
  });

  /// Combines first_name + last_name if name is empty or null.
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) {
      return name!;
    }
    final parts = <String>[
      if (firstName != null && firstName!.trim().isNotEmpty) firstName!.trim(),
      if (lastName != null && lastName!.trim().isNotEmpty) lastName!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    return email ?? company ?? '';
  }

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      firstName: (json['first_name'] ?? json['firstname'])?.toString(),
      lastName: (json['last_name'] ?? json['lastname'])?.toString(),
      email: json['email']?.toString(),
      phoneNumber: (json['phonenumber'] ?? json['phone'])?.toString(),
      company: json['company']?.toString(),
      title: json['title']?.toString(),
      status: json['status']?.toString(),
      leadStatus: json['lead_status']?.toString(),
      source: json['source']?.toString(),
      leadValue: json['lead_value']?.toString(),
      website: json['website']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      zip: json['zip']?.toString(),
      description: json['description']?.toString(),
      dateAdded: (json['dateadded'] ?? json['created_at'] ?? json['date_added'])?.toString(),
      hash: json['hash']?.toString(),
      addedFrom: json['addedfrom']?.toString(),
      leadOrder: json['leadorder']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phonenumber': phoneNumber,
      'company': company,
      'title': title,
      'status': status,
      'lead_status': leadStatus,
      'source': source,
      'lead_value': leadValue,
      'website': website,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'zip': zip,
      'description': description,
      'dateadded': dateAdded,
      'hash': hash,
      'addedfrom': addedFrom,
      'leadorder': leadOrder,
    };
  }

  static List<Lead> fromList(List<dynamic> list) {
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => Lead.fromJson(json))
        .toList();
  }

  @override
  String toString() => 'Lead(id: $id, displayName: $displayName)';
}
