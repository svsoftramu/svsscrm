class Customer {
  final String? id;
  final String? userId;
  final String? company;
  final String? contactName;
  final String? contactPerson;
  final String? contactEmail;
  final String? email;
  final String? phoneNumber;
  final String? contactPhone;
  final String? phone;
  final String? website;
  final String? vat;
  final String? gstNumber;
  final String? cinNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? zip;
  final String? billingStreet;
  final String? billingCity;
  final String? billingState;
  final String? billingZip;
  final String? shippingStreet;
  final String? shippingCity;
  final String? shippingState;
  final String? shippingZip;
  final String? dateCreated;

  Customer({
    this.id,
    this.userId,
    this.company,
    this.contactName,
    this.contactPerson,
    this.contactEmail,
    this.email,
    this.phoneNumber,
    this.contactPhone,
    this.phone,
    this.website,
    this.vat,
    this.gstNumber,
    this.cinNumber,
    this.address,
    this.city,
    this.state,
    this.zip,
    this.billingStreet,
    this.billingCity,
    this.billingState,
    this.billingZip,
    this.shippingStreet,
    this.shippingCity,
    this.shippingState,
    this.shippingZip,
    this.dateCreated,
  });

  /// Returns the best available display name for this customer.
  String get displayName {
    if (company != null && company!.trim().isNotEmpty) return company!;
    if (contactName != null && contactName!.trim().isNotEmpty) return contactName!;
    if (contactPerson != null && contactPerson!.trim().isNotEmpty) return contactPerson!;
    return email ?? contactEmail ?? '';
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString(),
      userId: json['userid']?.toString(),
      company: json['company']?.toString(),
      contactName: json['contact_name']?.toString(),
      contactPerson: json['contact_person']?.toString(),
      contactEmail: json['contact_email']?.toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phonenumber']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      phone: json['phone']?.toString(),
      website: json['website']?.toString(),
      vat: json['vat']?.toString(),
      gstNumber: json['gst_number']?.toString(),
      cinNumber: json['cin_number']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      zip: json['zip']?.toString(),
      billingStreet: json['billing_street']?.toString(),
      billingCity: json['billing_city']?.toString(),
      billingState: json['billing_state']?.toString(),
      billingZip: json['billing_zip']?.toString(),
      shippingStreet: json['shipping_street']?.toString(),
      shippingCity: json['shipping_city']?.toString(),
      shippingState: json['shipping_state']?.toString(),
      shippingZip: json['shipping_zip']?.toString(),
      dateCreated: (json['datecreated'] ?? json['created_at'] ?? json['date_created'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userid': userId,
      'company': company,
      'contact_name': contactName,
      'contact_person': contactPerson,
      'contact_email': contactEmail,
      'email': email,
      'phonenumber': phoneNumber,
      'contact_phone': contactPhone,
      'phone': phone,
      'website': website,
      'vat': vat,
      'gst_number': gstNumber,
      'cin_number': cinNumber,
      'address': address,
      'city': city,
      'state': state,
      'zip': zip,
      'billing_street': billingStreet,
      'billing_city': billingCity,
      'billing_state': billingState,
      'billing_zip': billingZip,
      'shipping_street': shippingStreet,
      'shipping_city': shippingCity,
      'shipping_state': shippingState,
      'shipping_zip': shippingZip,
      'datecreated': dateCreated,
    };
  }

  static List<Customer> fromList(List<dynamic> list) {
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => Customer.fromJson(json))
        .toList();
  }

  @override
  String toString() => 'Customer(id: $id, displayName: $displayName)';
}
