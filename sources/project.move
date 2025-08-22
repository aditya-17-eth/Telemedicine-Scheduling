module MyModule::TelemedicineScheduling {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    /// Error codes
    const E_APPOINTMENT_NOT_FOUND: u64 = 1;
    const E_APPOINTMENT_ALREADY_BOOKED: u64 = 2;
    const E_INSUFFICIENT_PAYMENT: u64 = 3;

    /// Struct representing a mental health consultation appointment
    struct Appointment has store, key {
        patient_address: address,     // Address of the patient who booked
        doctor_address: address,      // Address of the consulting doctor
        appointment_time: u64,        // Timestamp of the appointment
        consultation_fee: u64,        // Fee for the consultation in APT
        is_booked: bool,             // Status of the appointment
        session_type: u8,            // 1 = Telemedicine, 2 = Telepsychiatry
    }

    /// Struct to store doctor's availability and pricing
    struct DoctorSchedule has store, key {
        consultation_fee: u64,        // Fee per consultation
        available_slots: u64,         // Number of available appointment slots
        total_appointments: u64,      // Total appointments scheduled
    }

    /// Function for doctors to register and set their consultation schedule
    public fun register_doctor(
        doctor: &signer, 
        consultation_fee: u64, 
        available_slots: u64
    ) {
        let doctor_schedule = DoctorSchedule {
            consultation_fee,
            available_slots,
            total_appointments: 0,
        };
        move_to(doctor, doctor_schedule);
    }

    /// Function for patients to book a mental health consultation appointment
    public fun book_appointment(
        patient: &signer,
        doctor_address: address,
        appointment_time: u64,
        session_type: u8,
        payment_amount: u64
    ) acquires DoctorSchedule {
        let patient_address = signer::address_of(patient);
        
        // Get doctor's schedule and verify payment
        let doctor_schedule = borrow_global_mut<DoctorSchedule>(doctor_address);
        assert!(payment_amount >= doctor_schedule.consultation_fee, E_INSUFFICIENT_PAYMENT);
        assert!(doctor_schedule.available_slots > 0, E_APPOINTMENT_ALREADY_BOOKED);
        
        // Process payment - transfer consultation fee to doctor
        let payment = coin::withdraw<AptosCoin>(patient, doctor_schedule.consultation_fee);
        coin::deposit<AptosCoin>(doctor_address, payment);
        
        // Create and store the appointment
        let appointment = Appointment {
            patient_address,
            doctor_address,
            appointment_time,
            consultation_fee: doctor_schedule.consultation_fee,
            is_booked: true,
            session_type,
        };
        
        // Update doctor's schedule
        doctor_schedule.available_slots = doctor_schedule.available_slots - 1;
        doctor_schedule.total_appointments = doctor_schedule.total_appointments + 1;
        
        // Move appointment to patient's account
        move_to(patient, appointment);
    }
}