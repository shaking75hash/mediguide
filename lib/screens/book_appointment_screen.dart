import 'package:flutter/material.dart';

import '../services/api_service.dart';

class BookAppointmentScreen extends StatefulWidget {
  final int doctorId;
  final String doctorName;
  final String specialty;

  const BookAppointmentScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime? _selectedDate;
  List<String> _slots = [];
  String? _selectedSlot;
  bool _isLoadingSlots = false;
  bool _isBooking = false;

  Future<void> _loadSlots(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _slots = [];
      _selectedSlot = null;
    });
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      debugPrint('🔍 Loading slots for doctor ${widget.doctorId} on $dateStr');
      final slots = await ApiService.getSlots(widget.doctorId, dateStr);
      debugPrint('✅ Got ${slots.length} slots: $slots');
      if (mounted) setState(() => _slots = slots);
    } catch (e) {
      debugPrint('❌ Slot load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slot error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _book() async {
    if (_selectedDate == null || _selectedSlot == null) {
      debugPrint('⚠️ Book tapped but no date/slot selected');
      return;
    }
    setState(() => _isBooking = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      debugPrint(
        '📅 Booking doctor ${widget.doctorId} on $dateStr at $_selectedSlot',
      );
      final result = await ApiService.bookAppointment(
        widget.doctorId,
        dateStr,
        _selectedSlot!,
      );
      debugPrint('✅ Booking result: $result');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Appointment booked!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Booking error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canBook =
        _selectedDate != null && _selectedSlot != null && !_isBooking;

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.doctorName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(widget.specialty, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // ---- Date picker ----
            const Text(
              '1. Select a Date (Sun–Thu)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadSlots(picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate == null
                    ? 'Pick a date'
                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              ),
            ),

            const SizedBox(height: 24),

            // ---- Slots ----
            if (_selectedDate != null) ...[
              const Text(
                '2. Select a Time Slot',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _isLoadingSlots
                  ? const Center(child: CircularProgressIndicator())
                  : _slots.isEmpty
                  ? const Text(
                      'No slots available — Fri & Sat are off days',
                      style: TextStyle(color: Colors.grey),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _slots.map((slot) {
                        final isSelected = _selectedSlot == slot;
                        return ChoiceChip(
                          label: Text(slot),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedSlot = selected ? slot : null;
                            });
                            debugPrint(
                              '🕐 Slot tapped: $slot → selected=$selected',
                            );
                          },
                          selectedColor: Colors.blue.shade700,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        );
                      }).toList(),
                    ),
            ],

            const Spacer(),

            // ---- Confirm button ----
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: canBook ? _book : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: _isBooking
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        canBook ? 'Confirm Booking' : 'Pick date & slot first',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
