import 'package:flutter/material.dart';

class TransportMode {
  const TransportMode({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const transportModes = <TransportMode>[
  TransportMode(id: 'car', label: 'Car', icon: Icons.directions_car),
  TransportMode(id: 'bus', label: 'Bus', icon: Icons.directions_bus),
  TransportMode(id: 'train', label: 'Train', icon: Icons.train),
];

const allowedVehicleTypes = {'car', 'bus', 'train'};

TransportMode transportModeFor(String id) {
  return transportModes.firstWhere(
    (mode) => mode.id == id,
    orElse: () => TransportMode(id: id, label: id, icon: Icons.commute),
  );
}
