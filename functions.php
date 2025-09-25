function get_student_schedules($request) {
    // Log the request parameters
    error_log('Schedule Request: ' . print_r($request->get_params(), true));
    
    $student_id = (int) $request->get_param('student_id');
    $timestamp = $request->get_param('_t');
    
    if (!$student_id) {
        return new WP_Error('missing_id', 'Student ID is required', array('status' => 400));
    }
    
    // Only use cache if no timestamp is provided
    if (!$timestamp) {
        $cache_key = 'schedules_' . $student_id;
        $cached_schedules = wp_cache_get($cache_key, SCHEDULE_CACHE_GROUP);
        
        if ($cached_schedules !== false) {
            error_log('Returning cached schedules for student ' . $student_id);
            return $cached_schedules;
        }
    }
    
    // Cache miss or cache busting requested, need to fetch data
    global $wpdb;
    
    // Get user data for lesson name
    $user = get_userdata($student_id);
    if (!$user) {
        return new WP_Error('invalid_student', 'Student not found', array('status' => 404));
    }
    
    // Get lesson name from user meta
    $lesson_name = get_user_meta($student_id, 'lessons_name', true);
    
    // Get schedules from the database
    $table_name = $wpdb->prefix . 'student_schedules';
    $query = $wpdb->prepare(
        "SELECT * FROM $table_name WHERE student_id = %d",
        $student_id
    );
    
    error_log('Executing query: ' . $query);
    $schedules = $wpdb->get_results($query);
    error_log('Raw schedules from DB: ' . print_r($schedules, true));
    
    if (empty($schedules)) {
        error_log('No schedules found for student ' . $student_id);
        return array(); // Return empty array if no schedules found
    }
    
    $formatted_schedules = array();
    
    foreach ($schedules as $schedule) {
        // Get teacher name
        $teacher_name = get_teacher_name($schedule->teacher_id);
        
        // Parse the schedule JSON data
        $schedule_data = json_decode($schedule->schedule, true);
        if (!is_array($schedule_data)) {
            error_log('Failed to parse schedule data for student ' . $student_id . ': ' . $schedule->schedule);
            $schedule_data = array(); // Default to empty array if parsing fails
        }
        
        // Format for Flutter app
        $formatted_schedule = array(
            'id' => (int) $schedule->id,
            'student_id' => (int) $schedule->student_id,
            'teacher_id' => (int) $schedule->teacher_id,
            'teacher_name' => $teacher_name ?: 'N/A',
            'lesson_name' => $lesson_name ?: 'N/A',
            'lesson_duration' => (int) $schedule->lesson_duration,
            'schedules' => array_map(function($item) {
                return array(
                    'day' => isset($item['day']) ? $item['day'] : '',
                    'hour' => isset($item['hour']) ? $item['hour'] : '',
                    'original' => isset($item['original']) ? $item['original'] : null
                );
            }, $schedule_data)
        );
        
        $formatted_schedules[] = $formatted_schedule;
    }
    
    error_log('Formatted schedules: ' . print_r($formatted_schedules, true));
    
    // Only cache if no timestamp was provided
    if (!$timestamp) {
        wp_cache_set($cache_key, $formatted_schedules, SCHEDULE_CACHE_GROUP, CACHE_EXPIRATION);
        error_log('Cached schedules for student ' . $student_id);
    } else {
        error_log('Cache busting requested with timestamp: ' . $timestamp);
    }
    
    return $formatted_schedules;
}



/**
 * Get student reports - new function to match Flutter code
 * Returns formatted reports from wp_student_reports table
 */
function get_student_reports($request) {
    $student_id = (int) $request->get_param('student_id');
    $timestamp = $request->get_param('_t');
    
    if (!$student_id) {
        return new WP_Error('missing_id', 'Student ID is required', array('status' => 400));
    }
    
    // Only use cache if no timestamp is provided
    if (!$timestamp) {
        $cache_key = 'reports_' . $student_id;
        $cached_reports = wp_cache_get($cache_key, REPORT_CACHE_GROUP);
        
        if ($cached_reports !== false) {
            return $cached_reports;
        }
    }
    
    // Cache miss or cache busting requested, need to fetch data
    global $wpdb;
    
    // Verify student exists
    $user = get_userdata($student_id);
    if (!$user) {
        return new WP_Error('invalid_student', 'Student not found', array('status' => 404));
    }
    
    // Get reports from the database
    $table_name = $wpdb->prefix . 'student_reports';
    $query = $wpdb->prepare(
        "SELECT * FROM $table_name WHERE student_id = %d ORDER BY date DESC",
        $student_id
    );
    
    $reports = $wpdb->get_results($query);
    
    if (empty($reports)) {
        return array(); // Return empty array if no reports found
    }
    
    $formatted_reports = array();
    
    foreach ($reports as $report) {
        // Get teacher name
        $teacher_name = get_teacher_name($report->teacher_id);
        
        // Format for Flutter app to match StudentReport.fromJson
        $formatted_report = array(
            'id' => (int) $report->id,
            'studentId' => (int) $report->student_id,
            'teacherId' => (int) $report->teacher_id,
            'teacherName' => $teacher_name ?: 'N/A',
            'sessionNumber' => $report->session_number,
            'date' => $report->date,
            'time' => $report->time,
            'attendance' => $report->attendance,
            'evaluation' => $report->evaluation,
            'grade' => (int) $report->grade,
            'lessonDuration' => (int) $report->lesson_duration,
            'tasmii' => $report->tasmii,
            'tahfiz' => $report->tahfiz,
            'mourajah' => $report->mourajah,
            'nextTasmii' => $report->next_tasmii,
            'nextMourajah' => $report->next_mourajah,
            'notes' => $report->notes,
            'zoomImageUrl' => $report->zoom_image_url
        );
        
        $formatted_reports[] = $formatted_report;
    }
    
    // Only cache if no timestamp was provided
    if (!$timestamp) {
        wp_cache_set($cache_key, $formatted_reports, REPORT_CACHE_GROUP, CACHE_EXPIRATION);
    }
    
    return $formatted_reports;
} 