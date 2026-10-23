// lib/screens/customers/new_customer_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/image_picker_widget.dart';

class NewCustomerScreen extends StatefulWidget {
  const NewCustomerScreen({super.key});

  @override
  State<NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends State<NewCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  String _uploadedPhotoUrl = '';
  bool _isSubmitting = false;

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<CustomerProvider>();
    final newCust = await provider.createCustomer({
      'name': _nameCtrl.text.trim(),
      'mobile': _mobileCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'aadhaar_number': _aadhaarCtrl.text.trim(),
      'pan_number': _panCtrl.text.trim(),
      'photo_url': _uploadedPhotoUrl,
    });

    setState(() => _isSubmitting = false);

    if (newCust != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer ${newCust.name} (${newCust.customerCode}) created successfully!'),
          backgroundColor: const Color(0xFF065F46),
        ),
      );
      Navigator.of(context).pop(true);
    } else if (provider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final isMobile = width < 600;
        final isTablet = width >= 600 && width < 1000;
        final horizontalPadding = isMobile
            ? 14.0
            : isTablet
                ? 20.0
                : 24.0;

        return Container(
          width: double.infinity,
          height: isMobile ? MediaQuery.of(context).size.height : null,
          constraints: BoxConstraints(
            maxWidth: isMobile
                ? double.infinity
                : isTablet
                    ? 760
                    : 900,
            maxHeight: isMobile
                ? double.infinity
                : MediaQuery.of(context).size.height * 0.94,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 0 : 16),
            boxShadow: isMobile
                ? null
                : const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _buildHeader(isMobile),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isMobile ? 14 : 20,
                    horizontalPadding,
                    isMobile ? 14 : 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAutomaticIdNotice(isMobile),
                        SizedBox(height: isMobile ? 14 : 18),

                        // Customer photograph.
                        ImagePickerWidget(
                          uploadType: 'customers',
                          label: 'Customer Photograph (Camera / Gallery)',
                          onImageUploaded: (url) {
                            setState(() => _uploadedPhotoUrl = url);
                          },
                        ),

                        SizedBox(height: isMobile ? 14 : 18),

                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Customer Full Name *',
                            hintText: 'e.g. Ravi Kumar',
                            prefixIcon: Icon(
                              Icons.person,
                              color: AppTheme.goldDark,
                            ),
                          ),
                          validator: (val) => (val == null ||
                                  val.trim().isEmpty)
                              ? 'Customer name is required'
                              : null,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),

                        TextFormField(
                          controller: _mobileCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number *',
                            hintText: 'e.g. 9876543210',
                            prefixIcon: Icon(
                              Icons.phone,
                              color: AppTheme.goldDark,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Mobile number is required';
                            }
                            final cleaned = val.trim().replaceAll(RegExp(r'[\s\-\+]'), '');
                            if (!RegExp(r'^[0-9]{10}$').hasMatch(cleaned)) {
                              return 'Enter valid 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isMobile ? 12 : 16),

                        TextFormField(
                          controller: _addressCtrl,
                          maxLines: isMobile ? 3 : 2,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full Residential Address *',
                            hintText: 'Door No, Street Name, City, Pincode',
                            prefixIcon: Icon(
                              Icons.home,
                              color: AppTheme.goldDark,
                            ),
                            alignLabelWithHint: true,
                          ),
                          validator: (val) => (val == null ||
                                  val.trim().isEmpty)
                              ? 'Address is required'
                              : null,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),

                        if (isMobile)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _aadhaarCtrl,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Aadhaar (Optional)',
                                  hintText: '12-digit number',
                                  prefixIcon: Icon(
                                    Icons.credit_card,
                                    color: AppTheme.silverDark,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return null;
                                  final cleaned = val.trim().replaceAll(RegExp(r'[\s\-]'), '');
                                  if (!RegExp(r'^[0-9]{12}$').hasMatch(cleaned)) {
                                    return 'Aadhaar must be a 12-digit number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _panCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'PAN (Optional)',
                                  hintText: 'ABCDE1234F',
                                  prefixIcon: Icon(
                                    Icons.badge,
                                    color: AppTheme.silverDark,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return null;
                                  final cleaned = val.trim().toUpperCase();
                                  if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(cleaned)) {
                                    return 'Enter valid PAN (e.g. ABCDE1234F)';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _aadhaarCtrl,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Aadhaar (Optional)',
                                    hintText: '12-digit number',
                                    prefixIcon: Icon(
                                      Icons.credit_card,
                                      color: AppTheme.silverDark,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return null;
                                    final cleaned = val.trim().replaceAll(RegExp(r'[\s\-]'), '');
                                    if (!RegExp(r'^[0-9]{12}$').hasMatch(cleaned)) {
                                      return 'Aadhaar must be a 12-digit number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _panCtrl,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: 'PAN (Optional)',
                                    hintText: 'ABCDE1234F',
                                    prefixIcon: Icon(
                                      Icons.badge,
                                      color: AppTheme.silverDark,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return null;
                                    final cleaned = val.trim().toUpperCase();
                                    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(cleaned)) {
                                      return 'Enter valid PAN (e.g. ABCDE1234F)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                        SizedBox(height: isMobile ? 18 : 24),

                        if (isMobile)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                child: const Text('CANCEL'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed:
                                    _isSubmitting ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.goldPrimary,
                                  foregroundColor: AppTheme.darkNavy,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: AppTheme.darkNavy,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'SAVE CUSTOMER',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('CANCEL'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed:
                                    _isSubmitting ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.goldPrimary,
                                  foregroundColor: AppTheme.darkNavy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: AppTheme.darkNavy,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'SAVE CUSTOMER',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isMobile ? 0 : 16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 34 : 38,
            height: isMobile ? 34 : 38,
            decoration: BoxDecoration(
              color: AppTheme.goldPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.person_add,
              color: AppTheme.goldPrimary,
              size: isMobile ? 19 : 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Register New Customer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: const Icon(
              Icons.close,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomaticIdNotice(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 9 : 10),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.silverBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: AppTheme.goldDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Customer Code will be generated automatically (e.g. CUS-000001)',
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkNavy,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
