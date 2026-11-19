UPDATE doctors
SET is_sample = TRUE,
    is_verified = FALSE,
    qualification = 'Demo-only sample profile; qualification is not real'
WHERE name IN (
    'Dr. Abdul Mannan',
    'Dr. Farhana Akter',
    'Dr. Rafiqul Islam',
    'Dr. Nasrin Sultana',
    'Dr. Kamal Hossain',
    'Dr. Shamsun Nahar',
    'Dr. Mizanur Rahman',
    'Dr. Tahmina Begum',
    'Dr. Jahangir Alam',
    'Dr. Sabina Yasmin',
    'Dr. Mahmud Hasan',
    'Dr. Ayesha Siddika'
);
