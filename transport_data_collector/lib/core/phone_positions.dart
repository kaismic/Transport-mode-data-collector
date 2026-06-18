class PhonePosition {
  const PhonePosition({required this.id, required this.label});

  final String id;
  final String label;
}

const phonePositions = <PhonePosition>[
  PhonePosition(id: 'hand', label: 'Hand'),
  PhonePosition(id: 'pocket', label: 'Pocket'),
  PhonePosition(id: 'bag', label: 'Bag'),
  PhonePosition(id: 'stationary', label: 'Stationary'),
  PhonePosition(id: 'other', label: 'Other'),
];

const allowedPhonePositions = {'hand', 'pocket', 'bag', 'stationary', 'other'};

PhonePosition phonePositionFor(String id) {
  return phonePositions.firstWhere(
    (position) => position.id == id,
    orElse: () => const PhonePosition(id: 'other', label: 'Other'),
  );
}
