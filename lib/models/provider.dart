class Provider {
  final String id;
  final String name;
  final String type;
  final String specialty;
  final String location;
  final double rating;
  final int reviewCount;
  final double price;
  final String imageUrl;
  final String email;
  final String phone;
  final String workingHours;

  Provider({
    required this.id,
    required this.name,
    required this.type,
    required this.specialty,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.price,
    required this.imageUrl,
    required this.email,
    required this.phone,
    required this.workingHours,
  });
}
