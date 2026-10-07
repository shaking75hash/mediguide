import 'package:flutter/material.dart';

import '../services/appointment_notification_service.dart';
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
      await ApiService.bookAppointment(
        widget.doctorId,
        dateStr,
        _selectedSlot!,
      );
      var reminderMessage = 'Appointment booked.';
      try {
        final permitted =
            await AppointmentNotificationService.requestReminderPermissions();
        if (!permitted) {
          reminderMessage =
              'Appointment booked. Enable notifications and exact alarms in your profile for a 30-minute reminder.';
        } else {
          final appointments = await ApiService.getMyAppointments();
          final scheduled =
              await AppointmentNotificationService.syncIfPermitted(
            appointments,
          );
          if (!scheduled) {
            reminderMessage =
                'Appointment booked, but reminder permissions are not enabled.';
          }
        }
      } catch (error) {
        debugPrint('Could not schedule appointment reminder: $error');
        reminderMessage =
            'Appointment booked, but the reminder could not be scheduled. Check notification permissions in your profile.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reminderMessage == 'Appointment booked.'
                  ? 'Appointment booked with ${widget.doctorName}.'
                  : reminderMessage,
            ),
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
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
              Text(
                widget.doctorName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.specialty,
                style: const TextStyle(color: Colors.grey),
              ),
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

          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: canBook ? _book : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
