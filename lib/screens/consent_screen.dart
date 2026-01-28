import 'package:flutter/material.dart';
import 'signup_screen.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  String? _selectedConsent;

  void _handleAgree() {
    if (_selectedConsent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an option'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedConsent == 'agree') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignupScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to continue registration'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0a1e5e), Color(0xFF1a3a8a), Color(0xFF2563eb)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563eb), Color(0xFF1e40af)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 60,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/unai_logo.png',
                      width: 200,
                      height: 120,
                    ),
                    const SizedBox(height: 16),

                    // Title
                    const Text(
                      'UNAi Chat',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Consent Box
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Consent Title
                          const Text(
                            'ความยินยอมในการเก็บรวบรวม ใช้ และบันทึกข้อมูลการสนทนา',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Scrollable Consent Content
                          Container(
                            height: 280,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Scrollbar(
                              thumbVisibility: true,
                              thickness: 6,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ข้าพเจ้ายินยอมให้ระบบแชทบอททำการเก็บรวบรวม ใช้ และบันทึกข้อมูลการสนทนาของข้าพเจ้า ซึ่งรวมถึงข้อความที่ใช้สนทนากับแชทบอท วันและเวลาที่ใช้งาน เพื่อวัตถุประสงค์ดังต่อไปนี้',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      '1. เพื่อจัดเก็บประวัติการสนทนาและแสดงผลย้อนหลังแก่ผู้ใช้งาน\n2. เพื่อปรับปรุง พัฒนา และเพิ่มประสิทธิภาพการให้บริการของระบบแชทบอท',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'ระบบจะเก็บรวบรวมและใช้ข้อมูลดังกล่าวเฉพาะตามวัตถุประสงค์ที่ระบุไว้เท่านั้น และจะไม่เปิดเผยข้อมูลแก่บุคคลภายนอก เว้นแต่เป็นไปตามที่กฎหมายกำหนด',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'ระยะเวลาการจัดเก็บข้อมูล',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'ระบบจะจัดเก็บข้อมูลการสนทนาของท่านตลอดระยะเวลาที่ท่านมีบัญชีผู้ใช้งานในระบบ หรือจนกว่าท่านจะใช้สิทธิ์ในการลบข้อมูลหรือยกเลิกบัญชีผู้ใช้งาน',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'สิทธิในการจัดการข้อมูล',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'ข้าพเจ้าทราบและเข้าใจว่า',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '• ข้าพเจ้าสามารถเลือก ลบประวัติการสนทนาเฉพาะบางรายการ ได้ด้วยตนเอง\n• หรือสามารถเลือก ลบบัญชีผู้ใช้งาน ซึ่งระบบจะดำเนินการลบข้อมูลการสนทนาและข้อมูลที่เกี่ยวข้องทั้งหมดออกจากระบบอย่างถาวร',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'โดยการลบบัญชีผู้ใช้งานถือเป็นการถอนความยินยอมในการเก็บรวบรวมและใช้ข้อมูลทั้งหมด',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'กรณีไม่ให้ความยินยอม',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'หากข้าพเจ้าไม่ให้ความยินยอม ระบบจะไม่ทำการบันทึกประวัติการสนทนา และข้าพเจ้าสามารถเลือกใช้งานระบบในโหมด Guest ซึ่งจะไม่มีการจัดเก็บข้อมูลการสนทนาใด ๆ',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Radio Options
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // ยินยอม
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedConsent = 'agree';
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Radio<String>(
                                        value: 'agree',
                                        groupValue: _selectedConsent,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedConsent = value;
                                          });
                                        },
                                        activeColor: const Color(0xFF1e40af),
                                      ),
                                      const Text(
                                        'ยินยอม',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ไม่ยินยอม
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedConsent = 'disagree';
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Radio<String>(
                                        value: 'disagree',
                                        groupValue: _selectedConsent,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedConsent = value;
                                          });
                                        },
                                        activeColor: const Color(0xFF1e40af),
                                      ),
                                      const Text(
                                        'ไม่ยินยอม',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        // Cancel Button
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _handleCancel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1e3a8a),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Agree Button
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _handleAgree,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1e3a8a),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              child: const Text(
                                'AGREE',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
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
        ),
      ),
    );
  }
}
