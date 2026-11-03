import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/alert_service.dart';
import '../services/localization_service.dart';
import '../widgets/emergency_ui_components.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final String driverEmail;
  const EmergencyContactsScreen({super.key, required this.driverEmail});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dbService.getEmergencyContacts(widget.driverEmail);
      if (mounted) {
        setState(() {
          _contacts = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showContactDialog({Map<String, dynamic>? contactToEdit}) {
    final bool isEditing = contactToEdit != null;
    final nameController = TextEditingController(text: contactToEdit?['name'] ?? '');
    final phoneController = TextEditingController(
      text: contactToEdit != null
          ? (contactToEdit['phone'] ?? '').toString().replaceAll('+91', '')
          : '',
    );
    final relationController = TextEditingController(text: contactToEdit?['relationship'] ?? 'Family');
    bool isPrimary = contactToEdit?['isPrimary'] == true || _contacts.isEmpty;
    bool receiveAlerts = contactToEdit?['receiveAlerts'] != false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'edit_contact'.tr : 'add_contact'.tr,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFFB7185)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFFFB7185),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'contact_name'.tr,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'contact_phone'.tr,
                      prefixText: "+91 ",
                      prefixIcon: const Icon(Icons.phone_outlined),
                      hintText: "9876543210",
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: relationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'contact_relation'.tr,
                      prefixIcon: const Icon(Icons.people_outline),
                      hintText: "e.g. Father, Spouse, Doctor",
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'primary_contact'.tr,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'make_primary'.tr,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    value: isPrimary,
                    activeThumbColor: const Color(0xFF38BDF8),
                    onChanged: (val) {
                      setModalState(() {
                        isPrimary = val;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'receive_alerts'.tr,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'receive_alerts_desc'.tr,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    value: receiveAlerts,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setModalState(() {
                        receiveAlerts = val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  InteractivePressable(
                    onTap: () async {
                      final name = nameController.text.trim();
                      final rawPhone = phoneController.text.trim();
                      final relation = relationController.text.trim();

                      if (name.isEmpty) {
                        setModalState(() {
                          errorMessage = "Please enter contact name.";
                        });
                        return;
                      }

                      if (!DatabaseService.isValidIndianMobile(rawPhone)) {
                        setModalState(() {
                          errorMessage = 'invalid_phone'.tr;
                        });
                        return;
                      }

                      final fullPhone = DatabaseService.normalizePhoneNumber(rawPhone);

                      // Check duplicate phone
                      final isDuplicate = _contacts.any((c) =>
                          c['id'] != contactToEdit?['id'] &&
                          DatabaseService.normalizePhoneNumber(c['phone'] ?? '') == fullPhone);

                      if (isDuplicate) {
                        setModalState(() {
                          errorMessage = 'duplicate_phone'.tr;
                        });
                        return;
                      }

                      try {
                        await _dbService.saveEmergencyContact(widget.driverEmail, {
                          if (isEditing) 'id': contactToEdit['id'],
                          'name': name,
                          'phone': fullPhone,
                          'relationship': relation.isNotEmpty ? relation : 'Contact',
                          'isPrimary': isPrimary,
                          'receiveAlerts': receiveAlerts,
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing ? 'contact_updated'.tr : 'contact_added'.tr),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                          _loadContacts();
                        }
                      } catch (err) {
                        setModalState(() {
                          errorMessage = err.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'save'.tr,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteContact(Map<String, dynamic> contact) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'delete_contact_title'.tr,
            style: const TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "${'delete_contact_confirm'.tr}\n\n• ${contact['name']} (${contact['phone']})",
            style: const TextStyle(fontFamily: 'Inter', color: Color(0xFFCBD5E1), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr, style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _dbService.deleteEmergencyContact(widget.driverEmail, contact['id']);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('contact_deleted'.tr),
                      backgroundColor: const Color(0xFFE11D48),
                    ),
                  );
                  _loadContacts();
                }
              },
              child: Text('delete'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalization.languageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'emergency_contacts'.tr,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8), size: 26),
                tooltip: 'add_contact'.tr,
                onPressed: () => _showContactDialog(),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
              : _contacts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.contacts_outlined, size: 40, color: Color(0xFF38BDF8)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'no_contacts'.tr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.5,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 24),
                            InteractivePressable(
                              onTap: () => _showContactDialog(),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE11D48),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'add_contact'.tr,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        final bool isPrimary = contact['isPrimary'] == true;
                        final bool receivesAlerts = contact['receiveAlerts'] != false;
                        final String phone = contact['phone'] ?? '';
                        final String maskedPhone = AlertService.maskPhoneNumber(phone);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161E2E),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isPrimary ? const Color(0xFF38BDF8) : const Color(0xFF26334D),
                              width: isPrimary ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isPrimary
                                        ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                                        : const Color(0xFF334155),
                                    child: Icon(
                                      Icons.person,
                                      color: isPrimary ? const Color(0xFF38BDF8) : Colors.white70,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                contact['name'] ?? 'Emergency Contact',
                                                style: const TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isPrimary) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFF38BDF8)),
                                                ),
                                                child: Text(
                                                  'primary_contact'.tr,
                                                  style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF38BDF8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: receivesAlerts
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                    : const Color(0xFF64748B).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: receivesAlerts
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                              child: Text(
                                                receivesAlerts ? 'SMS Active' : 'SMS Muted',
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: receivesAlerts
                                                      ? const Color(0xFF34D399)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          contact['relationship'] ?? 'Family',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                                    color: const Color(0xFF1E293B),
                                    onSelected: (val) async {
                                      if (val == 'edit') {
                                        _showContactDialog(contactToEdit: contact);
                                      } else if (val == 'primary') {
                                        await _dbService.setPrimaryEmergencyContact(widget.driverEmail, contact['id']);
                                        _loadContacts();
                                      } else if (val == 'delete') {
                                        _confirmDeleteContact(contact);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (!isPrimary)
                                        PopupMenuItem(
                                          value: 'primary',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.star_outline, size: 16, color: Color(0xFF38BDF8)),
                                              const SizedBox(width: 8),
                                              Text('make_primary'.tr, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                                            const SizedBox(width: 8),
                                            Text('edit'.tr, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFB7185)),
                                            const SizedBox(width: 8),
                                            Text('delete'.tr, style: const TextStyle(color: Color(0xFFFB7185), fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF1E293B)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone_iphone, size: 16, color: Color(0xFF10B981)),
                                    const SizedBox(width: 8),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        fontFamily: 'Courier',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      "Safe Mask: $maskedPhone",
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}
