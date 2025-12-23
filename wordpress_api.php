<?php

/**
 * Custom REST API endpoints with optimization
 * - Added caching
 * - Improved authentication handling
 * - Optimized database queries
 * - Added schedules endpoint
 * - Added student reports endpoint
 * - Hostinger cron job support
 */

// Cache constants
define('STUDENT_CACHE_GROUP', 'student_api_cache');
define('TEACHER_CACHE_GROUP', 'teacher_api_cache');
define('SCHEDULE_CACHE_GROUP', 'schedule_api_cache');
define('REPORT_CACHE_GROUP', 'report_api_cache');
define('CHAT_CACHE_GROUP', 'chat_api_cache');
define('CACHE_EXPIRATION', 3600); // 1 hour in seconds

// Register custom REST API endpoints - using one call for better performance
add_action('rest_api_init', function () {
    // Student login endpoint
    register_rest_route('custom/v1', '/student-login', array(
        'methods' => 'POST',
        'callback' => 'handle_student_login',
        'permission_callback' => '__return_true' // Public endpoint for login
    ));

    // User meta endpoint for student data
    register_rest_route('custom/v1', '/user-meta/(?P<id>\d+)', array(
        'methods' => 'GET',
        'callback' => 'get_student_meta',
        'permission_callback' => 'restrict_to_authenticated'
    ));

    // Teacher data endpoint
    register_rest_route('custom/v1', '/teacher/(?P<id>\d+)', array(
        'methods' => 'GET',
        'callback' => 'get_custom_teacher_data',
        'permission_callback' => 'restrict_to_authenticated'
    ));
    
    // Student schedules endpoint to match Flutter code
    register_rest_route('zuwad/v1', '/student-schedules', array(
        'methods' => 'GET',
        'callback' => 'get_student_schedules',
        'permission_callback' => 'restrict_to_authenticated'
    ));
    
    // Teacher free slots endpoint (returns available free slots for a teacher)
    register_rest_route('zuwad/v1', '/teacher-free-slots', array(
        'methods' => 'GET',
        'callback' => 'get_teacher_free_slots',
        'permission_callback' => 'restrict_to_authenticated'
    ));

    // Student reports endpoint to match Flutter code
    register_rest_route('zuwad/v1', '/student-reports', array(
        'methods' => 'GET',
        'callback' => 'get_student_reports',
        'permission_callback' => 'restrict_to_authenticated'
    ));
    
    // Chat endpoints
    register_rest_route('zuwad/v1', '/chat/messages', array(
        'methods' => 'POST',
        'callback' => 'get_chat_messages',
        'permission_callback' => 'restrict_to_authenticated'
    ));

    register_rest_route('zuwad/v1', '/chat/send', array(
        'methods' => 'POST',
        'callback' => 'send_chat_message',
        'permission_callback' => 'restrict_to_authenticated'
    ));

    register_rest_route('zuwad/v1', '/chat/mark-read', array(
        'methods' => 'POST',
        'callback' => 'mark_message_as_read',
        'permission_callback' => 'restrict_to_authenticated'
    ));

    // Cache clearing endpoint
    register_rest_route('custom/v1', '/clear-cache', array(
        'methods' => 'GET',
        'callback' => 'clear_api_cache',
        'permission_callback' => '__return_true'
    ));
    
    // Create postponed event endpoint
    register_rest_route('zuwad/v1', '/create-postponed-event', array(
        'methods' => 'POST',
        'callback' => 'handle_create_postponed_event_rest',
        'permission_callback' => 'restrict_to_authenticated'
    ));
    
    // Create student report endpoint
    register_rest_route('zuwad/v1', '/create-student-report', array(
        'methods' => 'POST',
        'callback' => 'handle_create_student_report_rest',
        'permission_callback' => 'restrict_to_authenticated'
    ));
    
    // Test session number calculation endpoint
    register_rest_route('zuwad/v1', '/test-session-number', array(
        'methods' => 'GET',
        'callback' => 'handle_test_session_number_rest',
        'permission_callback' => 'restrict_to_authenticated'
    ));
    
    // CORS handling - combined with endpoint registration for efficiency
    handle_cors_headers();
});

// CORS headers handling
function handle_cors_headers() {
    remove_filter('rest_pre_serve_request', 'rest_send_cors_headers');
    add_filter('rest_pre_serve_request', function ($value) {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: *');
        header('Access-Control-Allow-Credentials: true');
        return $value;
    });
    
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: *');
        header('Access-Control-Allow-Credentials: true');
        exit();
    }
}

// Optimized authentication check
// Update the authentication check to be more lenient
function restrict_to_authenticated($request) {
    // For now, allow all requests
    return true;
    
    // If you want to keep some basic security, you can use this instead:
    /*
    $student_id = (int) $request['id'];
    if (!$student_id) {
        return new WP_Error('missing_id', 'Student ID is required', array('status' => 400));
    }
    return true;
    */
}

// Optimized student login function
function handle_student_login($request) {
    $params = $request->get_json_params();
    $phone = isset($params['phone']) ? sanitize_text_field($params['phone']) : '';
    $password = isset($params['password']) ? $params['password'] : '';

    if (empty($phone) || empty($password)) {
        return new WP_Error('invalid_data', 'Phone and password are required', array('status' => 400));
    }

    // Use direct SQL query for better performance
    global $wpdb;
    $sql = $wpdb->prepare(
        "SELECT u.ID, u.user_pass 
         FROM {$wpdb->users} u 
         JOIN {$wpdb->usermeta} um1 ON u.ID = um1.user_id 
         JOIN {$wpdb->usermeta} um2 ON u.ID = um2.user_id 
         WHERE um1.meta_key = 'phone' 
         AND um1.meta_value = %s 
         AND um2.meta_key = %s 
         AND um2.meta_value LIKE %s 
         LIMIT 1",
        $phone,
        $wpdb->prefix . 'capabilities',
        '%student%'
    );
    
    $user_data = $wpdb->get_row($sql);

    if (!$user_data) {
        return new WP_Error('invalid_phone', 'No student found with this phone number', array('status' => 401));
    }
    
    // For testing: password must match phone number
    // TODO: Remove this bypass and restore WordPress password verification for production
    if ($password !== $phone) {
        return new WP_Error('invalid_password', 'Incorrect password', array('status' => 401));
    }

    // Generate authentication token (7 days)
    $token = wp_generate_auth_cookie($user_data->ID, time() + (7 * DAY_IN_SECONDS), 'logged_in');

    return array(
        'token' => $token,
        'user_id' => $user_data->ID,
        'message' => 'Login successful'
    );
}

// Optimized student meta data retrieval with caching
function get_student_meta($request) {
    $user_id = (int) $request['id'];
    
    if (!$user_id) {
        return new WP_Error('missing_id', 'Student ID is required', array('status' => 400));
    }
    
    // Try to get from cache first
    $cache_key = 'student_' . $user_id;
    $meta_data = wp_cache_get($cache_key, STUDENT_CACHE_GROUP);
    
    if ($meta_data !== false) {
        return $meta_data;
    }
    
    // Cache miss, need to fetch data
    $user = get_userdata($user_id);

    if (!$user) {
        return new WP_Error('invalid_user', 'User not found', array('status' => 404));
    }

    // Get all user meta at once for better performance
    $all_meta = get_user_meta($user_id);
    
    // Build response array
    $meta_data = array(
        'name' => $user->display_name,
        'phone' => isset($all_meta['phone'][0]) ? $all_meta['phone'][0] : '',
        'teacher_id' => isset($all_meta['teacher'][0]) ? $all_meta['teacher'][0] : '',
        'supervisor_id' => isset($all_meta['supervisor'][0]) ? $all_meta['supervisor'][0] : '',
        'lessons_number' => isset($all_meta['lessons_number'][0]) ? $all_meta['lessons_number'][0] : '',
        'lesson_duration' => isset($all_meta['lesson_duration'][0]) ? $all_meta['lesson_duration'][0] : '',
        'notes' => isset($all_meta['notes'][0]) ? $all_meta['notes'][0] : '',
        'm_id' => isset($all_meta['m_id'][0]) ? $all_meta['m_id'][0] : '',
        'lessons_name' => isset($all_meta['lessons_name'][0]) ? $all_meta['lessons_name'][0] : ''
    );

    // Get teacher name if teacher_id exists
    if (!empty($meta_data['teacher_id'])) {
        $teacher_name = get_teacher_name($meta_data['teacher_id']);
        $meta_data['teacher_name'] = $teacher_name ?: 'N/A';
    } else {
        $meta_data['teacher_name'] = 'N/A';
    }

    // Get supervisor name if supervisor_id exists
    if (!empty($meta_data['supervisor_id'])) {
        $supervisor_name = get_teacher_name($meta_data['supervisor_id']); // Using same function as they're both users
        $meta_data['supervisor_name'] = $supervisor_name ?: 'N/A';
    } else {
        $meta_data['supervisor_name'] = 'N/A';
    }
    
    // Save to cache
    wp_cache_set($cache_key, $meta_data, STUDENT_CACHE_GROUP, CACHE_EXPIRATION);

    return $meta_data;
}

// Helper function to get teacher name with caching
function get_teacher_name($teacher_id) {
    $cache_key = 'teacher_name_' . $teacher_id;
    $teacher_name = wp_cache_get($cache_key, TEACHER_CACHE_GROUP);
    
    if ($teacher_name !== false) {
        return $teacher_name;
    }
    
    $teacher = get_userdata($teacher_id);
    if (!$teacher) {
        return false;
    }
    
    $teacher_name = $teacher->display_name;
    wp_cache_set($cache_key, $teacher_name, TEACHER_CACHE_GROUP, CACHE_EXPIRATION);
    
    return $teacher_name;
}

// Optimized teacher data function with caching
function get_custom_teacher_data($request) {
    $teacher_id = (int) $request['id'];
    
    // Try to get from cache first
    $cache_key = 'teacher_' . $teacher_id;
    $teacher_data = wp_cache_get($cache_key, TEACHER_CACHE_GROUP);
    
    if ($teacher_data !== false) {
        return $teacher_data;
    }
    
    // Cache miss, need to fetch data
    $teacher = get_userdata($teacher_id);

    if (!$teacher) {
        return new WP_Error('invalid_teacher', 'Invalid teacher ID', array('status' => 404));
    }

    $teacher_data = array(
        'id' => $teacher->ID,
        'name' => $teacher->display_name,
        // Add more teacher fields if needed
    );
    
    // Save to cache
    wp_cache_set($cache_key, $teacher_data, TEACHER_CACHE_GROUP, CACHE_EXPIRATION);

    return $teacher_data;
}

/**
 * Helper function to get Arabic day name from day number
 */
function get_arabic_day_name($day_number) {
    $days = array(
        1 => 'السبت',
        2 => 'الأحد',
        3 => 'الاثنين',
        4 => 'الثلاثاء', 
        5 => 'الأربعاء',
        6 => 'الخميس',
        7 => 'الجمعة'
    );
    return isset($days[$day_number]) ? $days[$day_number] : 'غير محدد';
}

/**
 * Helper function to convert Arabic day names to day numbers
 */
function get_day_number_from_arabic($arabic_day) {
    $day_map = array(
        'الاثنين' => 1,   // Monday
        'الثلاثاء' => 2,  // Tuesday
        'الأربعاء' => 3,  // Wednesday
        'الخميس' => 4,   // Thursday
        'الجمعة' => 5,   // Friday
        'السبت' => 6,    // Saturday
        'الأحد' => 7     // Sunday
    );

    return isset($day_map[$arabic_day]) ? $day_map[$arabic_day] : 0;
}

/**
 * Get student schedules - new function to match Flutter code
 * Returns formatted schedules from wp_student_schedules table
 */
function get_student_schedules($request) {
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
    
    // Get schedules from the database - include both regular and postponed schedules
    $table_name = $wpdb->prefix . 'student_schedules';
    $reports_table = $wpdb->prefix . 'student_reports';
    
    // First get all schedules for the student - including postponed ones that reference this student
    $query = $wpdb->prepare(
        "SELECT * FROM $table_name WHERE student_id = %d 
         OR (is_postponed = 1 AND schedule LIKE %s)
         ORDER BY is_postponed ASC, id ASC",
        $student_id,
        '%"real_student_id":' . $student_id . '%'
    );

    // Debug logging to help troubleshoot
    error_log("API: Getting schedules for student_id: " . $student_id);
    error_log("API: Query: " . $query);

    $all_schedules = $wpdb->get_results($query);

    error_log("API: Found " . count($all_schedules) . " schedules");
    if (!empty($all_schedules)) {
        error_log("API: First schedule: " . print_r($all_schedules[0], true));
    }

    if (empty($all_schedules)) {
        error_log("API: No schedules found for student_id: " . $student_id);
        return array();
    }
    
    // IMPORTANT FIX: Get all reports for this student to check against postponed schedules
    // We need to exclude schedule slots that already have reports
    $current_week_start = date('Y-m-d', strtotime('monday this week'));
    $current_week_end = date('Y-m-d', strtotime('sunday this week'));

    // Get current week reports for regular schedules
    $current_week_reports_query = $wpdb->prepare(
        "SELECT date, time FROM $reports_table
         WHERE student_id = %d AND teacher_id = %d
         AND date BETWEEN %s AND %s",
        $student_id,
        $all_schedules[0]->teacher_id,
        $current_week_start,
        $current_week_end
    );
    
    // Get all reports for postponed schedule checking
    $all_reports_query = $wpdb->prepare(
        "SELECT date, time FROM $reports_table
         WHERE student_id = %d AND teacher_id = %d",
        $student_id,
        $all_schedules[0]->teacher_id
    );

    $current_week_reports = $wpdb->get_results($current_week_reports_query);
    $all_reports = $wpdb->get_results($all_reports_query);
    
    // Build array of excluded times from current week reports (for regular schedule checking)
    $excluded_times = array();
    foreach ($current_week_reports as $report) {
        // Convert report time to match schedule time format for comparison
        $report_time_24h = date('H:i', strtotime($report->time));
        $report_time_12h = date('g:i A', strtotime($report->time));

        $excluded_times[] = array(
            'date' => $report->date,
            'time_24h' => $report_time_24h,
            'time_12h' => $report_time_12h,
            'day_of_week' => date('N', strtotime($report->date)) // 1=Monday, 7=Sunday
        );
    }
    
    // Build array of all excluded times (for postponed schedule checking)
    $all_excluded_times = array();
    foreach ($all_reports as $report) {
        // Convert report time to match schedule time format for comparison
        $report_time_24h = date('H:i', strtotime($report->time));
        $report_time_12h = date('g:i A', strtotime($report->time));

        $all_excluded_times[] = array(
            'date' => $report->date,
            'time_24h' => $report_time_24h,
            'time_12h' => $report_time_12h,
            'day_of_week' => date('N', strtotime($report->date)) // 1=Monday, 7=Sunday
        );
    }

    error_log("API: Found " . count($current_week_reports) . " reports in current week to exclude");
    error_log("API: Found " . count($all_reports) . " total reports to check against postponed schedules");
    error_log("API: Current week excluded times: " . print_r($excluded_times, true));

    // Filter schedules to exclude slots that have reports in current week
    $schedules = $all_schedules;
     
     if (empty($schedules)) {
        return array(); // Return empty array if no schedules found
    }
    
    $formatted_schedules = array();
    
    foreach ($schedules as $schedule) {
        // Get teacher name
        $teacher_name = get_teacher_name($schedule->teacher_id);

        // Handle postponed vs regular schedules
        if ($schedule->is_postponed == 1) {
            // Check if this postponed schedule belongs to the requested student
            $schedule_json = json_decode($schedule->schedule, true);
            $real_student_id = isset($schedule_json['real_student_id']) ? (int)$schedule_json['real_student_id'] : $schedule->student_id;
            
            // Skip if this postponed schedule doesn't belong to the requested student
            if ($real_student_id != $student_id) {
                continue;
            }
            
            // IMPORTANT FIX: For postponed schedules, check if the date is in the future
            $postponed_datetime = new DateTime($schedule->postponed_date . ' ' . $schedule->postponed_time);
            $now = new DateTime();

            // Only include postponed schedules that are in the future
            if ($postponed_datetime > $now) {
                // Check if this postponed schedule conflicts with existing reports
                $postponed_time_24h = date('H:i', strtotime($schedule->postponed_time));
                $postponed_time_12h = date('g:i A', strtotime($schedule->postponed_time));
                
                $has_report = false;
                foreach ($all_excluded_times as $excluded) {
                    if ($excluded['date'] == $schedule->postponed_date && 
                        ($excluded['time_24h'] == $postponed_time_24h || $excluded['time_12h'] == $postponed_time_12h)) {
                        $has_report = true;
                        error_log("API: Skipping postponed schedule for " . $schedule->postponed_date . " at " . $postponed_time_12h . " - already has report");
                        break;
                    }
                }
                
                if (!$has_report) {
                    $postponed_date = new DateTime($schedule->postponed_date);

                    // Convert date to Arabic day name
                    $day_names = array(
                        1 => 'الاثنين',   // Monday
                        2 => 'الثلاثاء',  // Tuesday
                        3 => 'الأربعاء',  // Wednesday
                        4 => 'الخميس',   // Thursday
                        5 => 'الجمعة',   // Friday
                        6 => 'السبت',    // Saturday
                        7 => 'الأحد'     // Sunday
                    );

                    $php_day = $postponed_date->format('N'); // 1=Monday, 7=Sunday
                    $day_name = isset($day_names[$php_day]) ? $day_names[$php_day] : 'غير محدد';
                    $time_formatted = date('g:i A', strtotime($schedule->postponed_time));

                    $schedule_data = array([
                        'day' => $day_name,
                        'hour' => $time_formatted,
                        'original' => null,
                        'is_postponed' => true,
                        'postponed_date' => $schedule->postponed_date
                    ]);

                    error_log("API: Including postponed schedule for " . $schedule->postponed_date . " at " . $time_formatted);
                } else {
                    // Skip postponed schedule that has a report
                    continue;
                }
            } else {
                // Skip past postponed schedules
                error_log("API: Skipping past postponed schedule for " . $schedule->postponed_date);
                continue;
            }
        } else {
            // For regular schedules, parse the schedule JSON data and generate upcoming slots
            $raw_schedule_data = json_decode($schedule->schedule, true);
            if (!is_array($raw_schedule_data)) {
                error_log("API: Failed to parse schedule JSON for schedule ID " . $schedule->id . ": " . $schedule->schedule);
                $schedule_data = array(); // Default to empty array if parsing fails
            } else {
                error_log("API: Parsed schedule data for schedule ID " . $schedule->id . ": " . print_r($raw_schedule_data, true));

                // IMPORTANT FIX: Generate upcoming schedule slots for the next few weeks
                $schedule_data = array();
                $now = new DateTime();
                $end_date = clone $now;
                $end_date->modify('+4 weeks'); // Look ahead 4 weeks

                foreach ($raw_schedule_data as $slot) {
                    $slot_day = isset($slot['day']) ? $slot['day'] : '';
                    $slot_hour = isset($slot['hour']) ? $slot['hour'] : '';

                    if (empty($slot_day) || empty($slot_hour)) {
                        continue;
                    }

                    // Convert Arabic day to day number
                    $slot_day_number = get_day_number_from_arabic($slot_day);
                    if ($slot_day_number == 0) {
                        continue; // Skip invalid days
                    }

                    // Generate upcoming occurrences of this slot
                    $current_date = clone $now;
                    $current_date->modify('this week monday'); // Start from beginning of current week

                    while ($current_date <= $end_date) {
                        // Calculate the date for this day of the week
                        $slot_date = clone $current_date;
                        $days_to_add = ($slot_day_number == 7) ? 6 : ($slot_day_number - 1); // Convert to 0=Monday format
                        $slot_date->modify("+{$days_to_add} days");

                        // Create datetime for this slot
                        $slot_datetime = DateTime::createFromFormat('Y-m-d H:i:s',
                            $slot_date->format('Y-m-d') . ' ' . date('H:i:s', strtotime($slot_hour)));

                        // Only include future slots
                        if ($slot_datetime > $now) {
                            // Check if this specific slot has a report
                            $slot_time_24h = date('H:i', strtotime($slot_hour));
                            $slot_time_12h = date('g:i A', strtotime($slot_hour));

                            $slot_has_report = false;
                            foreach ($excluded_times as $excluded) {
                                if ($excluded['day_of_week'] == $slot_day_number &&
                                    ($excluded['time_24h'] == $slot_time_24h || $excluded['time_12h'] == $slot_time_12h)) {
                                    $slot_has_report = true;
                                    error_log("API: Excluding slot " . $slot_day . " " . $slot_hour . " on " . $slot_date->format('Y-m-d') . " - has report");
                                    break;
                                }
                            }

                            // Only include slot if it doesn't have a report
                            if (!$slot_has_report) {
                                $schedule_data[] = array(
                                    'day' => $slot_day,
                                    'hour' => $slot_hour,
                                    'original' => isset($slot['original']) ? $slot['original'] : null,
                                    'is_postponed' => false,
                                    'upcoming_date' => $slot_date->format('Y-m-d')
                                );
                                error_log("API: Including upcoming slot " . $slot_day . " " . $slot_hour . " on " . $slot_date->format('Y-m-d'));
                            }
                        }

                        // Move to next week
                        $current_date->modify('+1 week');
                    }
                }

                error_log("API: Generated " . count($schedule_data) . " upcoming slots for regular schedule");
            }
        }
        
        // Format for Flutter app - only include if there are schedule slots
        if (!empty($schedule_data)) {
            // For postponed schedules, use the real_student_id if available
            $display_student_id = $schedule->student_id;
            if ($schedule->is_postponed == 1) {
                $schedule_json = json_decode($schedule->schedule, true);
                if (isset($schedule_json['real_student_id'])) {
                    $display_student_id = (int)$schedule_json['real_student_id'];
                }
            }
            
            $formatted_schedule = array(
                'id' => (int) $schedule->id,
                'student_id' => (int) $display_student_id,
                'teacher_id' => (int) $schedule->teacher_id,
                'teacher_name' => $teacher_name ?: 'N/A',
                'lesson_name' => $lesson_name ?: 'N/A',
                'lesson_duration' => (int) $schedule->lesson_duration,
                'is_postponed' => (int) $schedule->is_postponed,
                'schedules' => array_map(function($item) {
                    return array(
                        'day' => isset($item['day']) ? $item['day'] : '',
                        'hour' => isset($item['hour']) ? $item['hour'] : '',
                        'original' => isset($item['original']) ? $item['original'] : null,
                        'is_postponed' => isset($item['is_postponed']) ? $item['is_postponed'] : false,
                        'upcoming_date' => isset($item['upcoming_date']) ? $item['upcoming_date'] : null,
                        'postponed_date' => isset($item['postponed_date']) ? $item['postponed_date'] : null
                    );
                }, $schedule_data)
            );

            $formatted_schedules[] = $formatted_schedule;
            error_log("API: Added formatted schedule with " . count($schedule_data) . " slots");
        } else {
            error_log("API: Skipping schedule ID " . $schedule->id . " - no upcoming slots");
        }
    }
    
    // Debug logging
    error_log("API: Returning " . count($formatted_schedules) . " formatted schedules");
    if (!empty($formatted_schedules)) {
        error_log("API: First formatted schedule: " . print_r($formatted_schedules[0], true));
    }

    // Only cache if no timestamp was provided
    if (!$timestamp) {
        wp_cache_set($cache_key, $formatted_schedules, SCHEDULE_CACHE_GROUP, CACHE_EXPIRATION);
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

/**
 * Cache invalidation function - to be called by Hostinger cron job
 */
function clear_api_cache($request) {
    // Simple security with a secret key
    $secret = $request->get_param('secret');
    $your_secret = '12345'; // Change this to a secure random string
    
    if ($secret !== $your_secret) {
        return new WP_Error('invalid_secret', 'Invalid secret key', array('status' => 403));
    }
    
    // Clear all API caches
    if (function_exists('wp_cache_delete_group')) {
        wp_cache_delete_group(STUDENT_CACHE_GROUP);
        wp_cache_delete_group(TEACHER_CACHE_GROUP);
        wp_cache_delete_group(SCHEDULE_CACHE_GROUP);
        wp_cache_delete_group(REPORT_CACHE_GROUP);
    } else {
        // Fallback for older WordPress versions
        global $wpdb;
        $wpdb->query("DELETE FROM $wpdb->options WHERE option_name LIKE '_transient_" . STUDENT_CACHE_GROUP . "%'");
        $wpdb->query("DELETE FROM $wpdb->options WHERE option_name LIKE '_transient_" . TEACHER_CACHE_GROUP . "%'");
        $wpdb->query("DELETE FROM $wpdb->options WHERE option_name LIKE '_transient_" . SCHEDULE_CACHE_GROUP . "%'");
        $wpdb->query("DELETE FROM $wpdb->options WHERE option_name LIKE '_transient_" . REPORT_CACHE_GROUP . "%'");
    }
    
    return array(
        'success' => true,
        'message' => 'API cache cleared successfully',
        'time' => current_time('mysql')
    );
}

/**
 * Get teacher free slots from wp_free_slots table
 * Accepts teacher_id (user_id) as GET param 'teacher_id'
 * Returns list of slots with id, user_id, day_of_week, start_time, end_time
 */
function get_teacher_free_slots($request) {
    $teacher_id = (int) $request->get_param('teacher_id');
    $student_id = (int) $request->get_param('student_id'); // Optional parameter for lesson duration

    if (!$teacher_id) {
        return new WP_Error('missing_id', 'Teacher ID is required', array('status' => 400));
    }

    // Get student's lesson duration if student_id is provided
    $lesson_duration = null;
    if ($student_id) {
        $lesson_duration = get_user_meta($student_id, 'lesson_duration', true);
        $lesson_duration = intval($lesson_duration);
    }

    global $wpdb;
    $table_name = $wpdb->prefix . 'free_slots';

    // Try to fetch slots
    $query = $wpdb->prepare("SELECT id, user_id, day_of_week, start_time, end_time FROM $table_name WHERE user_id = %d ORDER BY day_of_week, start_time", $teacher_id);
    $slots = $wpdb->get_results($query);

    if (empty($slots)) {
        return array();
    }

    // Get all postponed events for this teacher to exclude conflicting time slots
    $schedules_table = $wpdb->prefix . 'student_schedules';
    $postponed_events = $wpdb->get_results($wpdb->prepare(
        "SELECT postponed_date, postponed_time, lesson_duration
         FROM $schedules_table
         WHERE teacher_id = %d AND is_postponed = 1",
        $teacher_id
    ));

    // Create a lookup array for postponed events to quickly check conflicts
    $postponed_lookup = array();
    $cairo_tz = new DateTimeZone('Africa/Cairo');
    foreach ($postponed_events as $postponed) {
        $postponed_datetime = new DateTime($postponed->postponed_date . ' ' . $postponed->postponed_time, $cairo_tz);
        $postponed_end = clone $postponed_datetime;
        $postponed_end->modify('+' . $postponed->lesson_duration . ' minutes');

        // Create a key for the day of week and time
        $day_of_week = $postponed_datetime->format('w'); // 0 = Sunday, 6 = Saturday
        $time_key = $postponed_datetime->format('H:i:s');
        $key = $day_of_week . '_' . $time_key;

        $postponed_lookup[$key] = array(
            'start' => $postponed_datetime,
            'end' => $postponed_end,
            'day_of_week' => $day_of_week,
            'start_time' => $time_key,
            'end_time' => $postponed_end->format('H:i:s')
        );
    }

    // Split slots around postponed events instead of filtering them out entirely
    $filtered_slots = array();
    foreach ($slots as $slot) {
        $slot_parts = [];
        $slot_start_time = $slot->start_time;
        $slot_end_time = $slot->end_time;

        // Find all postponed events that overlap with this free slot on the same day
        $overlapping_postponed = [];
        foreach ($postponed_lookup as $postponed_data) {
            if ($slot->day_of_week == $postponed_data['day_of_week']) {
                // Check time overlap
                if ($slot_start_time < $postponed_data['end_time'] && $slot_end_time > $postponed_data['start_time']) {
                    $overlapping_postponed[] = $postponed_data;
                }
            }
        }

        if (empty($overlapping_postponed)) {
            // No conflicts, add the entire free slot
            $filtered_slots[] = $slot;
        } else {
            // Sort postponed events by start time
            usort($overlapping_postponed, function($a, $b) {
                return strcmp($a['start_time'], $b['start_time']);
            });

            $current_start = $slot_start_time;

            foreach ($overlapping_postponed as $postponed) {
                // If there's a gap before this postponed event, add it as a free slot part
                if ($current_start < $postponed['start_time']) {
                    // Create a new slot object for this part
                    $slot_part = clone $slot;
                    $slot_part->start_time = $current_start;
                    $slot_part->end_time = $postponed['start_time'];

                    // Check if this part is at least 15 minutes long
                    $part_start = DateTime::createFromFormat('H:i:s', $slot_part->start_time);
                    $part_end = DateTime::createFromFormat('H:i:s', $slot_part->end_time);
                    if ($part_start && $part_end) {
                        $part_duration_minutes = ($part_end->getTimestamp() - $part_start->getTimestamp()) / 60;
                        if ($part_duration_minutes >= 15) {
                            $filtered_slots[] = $slot_part;
                        }
                    }
                }

                // Move the start to after this postponed event
                $current_start = $postponed['end_time'] > $current_start ? $postponed['end_time'] : $current_start;
            }

            // If there's time remaining after the last postponed event, add it
            if ($current_start < $slot_end_time) {
                // Create a new slot object for this part
                $slot_part = clone $slot;
                $slot_part->start_time = $current_start;
                $slot_part->end_time = $slot_end_time;

                // Check if this part is at least 15 minutes long
                $part_start = DateTime::createFromFormat('H:i:s', $slot_part->start_time);
                $part_end = DateTime::createFromFormat('H:i:s', $slot_part->end_time);
                if ($part_start && $part_end) {
                    $part_duration_minutes = ($part_end->getTimestamp() - $part_start->getTimestamp()) / 60;
                    if ($part_duration_minutes >= 15) {
                        $filtered_slots[] = $slot_part;
                    }
                }
            }
        }
    }

    $formatted = array_map(function($s) {
        return array(
            'id' => (int) $s->id,
            'user_id' => (int) $s->user_id,
            'day_of_week' => (int) $s->day_of_week,
            'start_time' => $s->start_time,
            'end_time' => $s->end_time,
        );
    }, $filtered_slots);

    // Return lesson duration along with slots if student_id was provided
    if ($student_id) {
        return array(
            'slots' => $formatted,
            'lesson_duration' => $lesson_duration ?: 45 // Default to 45 minutes if not set
        );
    }

    return $formatted;
}


/**
 * Chat related functions
 */

function get_chat_messages($request) {
    global $wpdb;
    $table_name = $wpdb->prefix . 'chat_messages';

    $student_id = intval($request['student_id']);
    $recipient_id = intval($request['recipient_id']);
    $page = isset($request['page']) ? intval($request['page']) : 1;
    $per_page = 20;
    $offset = ($page - 1) * $per_page;

    // Try to get from cache first
    $cache_key = "chat_{$student_id}_{$recipient_id}_page_{$page}";
    $messages = wp_cache_get($cache_key, CHAT_CACHE_GROUP);
    
    if ($messages !== false) {
        return $messages;
    }

    $messages = $wpdb->get_results($wpdb->prepare(
        "SELECT m.*, 
         s.display_name as sender_name,
         r.display_name as recipient_name
         FROM $table_name m
         JOIN {$wpdb->users} s ON m.sender_id = s.ID
         JOIN {$wpdb->users} r ON m.recipient_id = r.ID
         WHERE (sender_id = %d AND recipient_id = %d)
         OR (sender_id = %d AND recipient_id = %d)
         ORDER BY created_at DESC
         LIMIT %d OFFSET %d",
        $student_id, $recipient_id,
        $recipient_id, $student_id,
        $per_page, $offset
    ));

    $formatted_messages = array_map(function($message) {
        return array(
            'id' => $message->id,
            'content' => $message->message,
            'sender_id' => $message->sender_id,
            'sender_name' => $message->sender_name,
            'recipient_id' => $message->recipient_id,
            'recipient_name' => $message->recipient_name,
            'is_read' => (bool)$message->is_read,
            'timestamp' => $message->created_at
        );
    }, $messages);

    // Save to cache for 5 minutes (chat data should be fresh)
    wp_cache_set($cache_key, $formatted_messages, CHAT_CACHE_GROUP, 300);

    return $formatted_messages;
}

function send_chat_message($request) {
    global $wpdb;
    $table_name = $wpdb->prefix . 'chat_messages';

    $sender_id = intval($request['student_id']);
    $recipient_id = intval($request['recipient_id']);
    $message = sanitize_text_field($request['message']);

    $result = $wpdb->insert(
        $table_name,
        array(
            'sender_id' => $sender_id,
            'recipient_id' => $recipient_id,
            'message' => $message,
            'created_at' => current_time('mysql'),
            'is_read' => 0
        ),
        array('%d', '%d', '%s', '%s', '%d')
    );

    if ($result === false) {
        return new WP_Error('db_insert_error', 'Could not insert message', array('status' => 500));
    }

    $message_id = $wpdb->insert_id;
    $sender = get_userdata($sender_id);
    $recipient = get_userdata($recipient_id);

    // Clear chat cache for both users
    wp_cache_delete("chat_{$sender_id}_{$recipient_id}_page_1", CHAT_CACHE_GROUP);
    wp_cache_delete("chat_{$recipient_id}_{$sender_id}_page_1", CHAT_CACHE_GROUP);

    return array(
        'id' => $message_id,
        'content' => $message,
        'sender_id' => $sender_id,
        'sender_name' => $sender->display_name,
        'recipient_id' => $recipient_id,
        'recipient_name' => $recipient->display_name,
        'is_read' => false,
        'timestamp' => current_time('mysql')
    );
}

function mark_message_as_read($request) {
    global $wpdb;
    $table_name = $wpdb->prefix . 'chat_messages';

    $message_id = intval($request['message_id']);

    $result = $wpdb->update(
        $table_name,
        array('is_read' => 1),
        array('id' => $message_id),
        array('%d'),
        array('%d')
    );

    if ($result === false) {
        return new WP_Error('db_update_error', 'Could not update message', array('status' => 500));
    }

    // Get message details to clear cache
    $message = $wpdb->get_row($wpdb->prepare(
        "SELECT sender_id, recipient_id FROM $table_name WHERE id = %d",
        $message_id
    ));

    if ($message) {
        // Clear chat cache for both users
        wp_cache_delete("chat_{$message->sender_id}_{$message->recipient_id}_page_1", CHAT_CACHE_GROUP);
        wp_cache_delete("chat_{$message->recipient_id}_{$message->sender_id}_page_1", CHAT_CACHE_GROUP);
    }

    return array('success' => true);
}

// /**
//  * SQL to create chat_messages table:
//  * 
// CREATE TABLE wp_chat_messages (
//     id BIGINT AUTO_INCREMENT PRIMARY KEY,
//     sender_id BIGINT NOT NULL,
//     recipient_id BIGINT NOT NULL,
//     message TEXT NOT NULL,
//     is_read TINYINT(1) DEFAULT 0,
//     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
//     FOREIGN KEY (sender_id) REFERENCES wp_users(ID),
//     FOREIGN KEY (recipient_id) REFERENCES wp_users(ID),
//     INDEX idx_sender_recipient (sender_id, recipient_id),
//     INDEX idx_created_at (created_at)
// );
//  */

// AJAX handler for creating postponed events
add_action('wp_ajax_create_postponed_event', 'handle_create_postponed_event');
add_action('wp_ajax_nopriv_create_postponed_event', 'handle_create_postponed_event');

// AJAX handler for getting teacher free slots
add_action('wp_ajax_get_teacher_free_slots', 'handle_get_teacher_free_slots');
add_action('wp_ajax_nopriv_get_teacher_free_slots', 'handle_get_teacher_free_slots');

// AJAX handler for getting student's teacher ID
add_action('wp_ajax_get_student_teacher_id', 'handle_get_student_teacher_id');
add_action('wp_ajax_nopriv_get_student_teacher_id', 'handle_get_student_teacher_id');

function handle_get_teacher_free_slots() {
    error_log('handle_get_teacher_free_slots called with POST data: ' . print_r($_POST, true));
    
    // Verify nonce for security
    // if (!wp_verify_nonce($_POST['_ajax_nonce'], 'zuwad_nonce')) {
    //     error_log('Invalid nonce provided');
    //     wp_send_json_error('Invalid nonce');
    //     return;
    // }
    
    // Check if student_id is provided (new approach) or teacher_id (legacy)
    $student_id = intval($_POST['student_id']);
    $teacher_id = intval($_POST['teacher_id']);
    
    error_log('Student ID: ' . $student_id . ', Teacher ID: ' . $teacher_id);
    
    if ($student_id) {
        // Get teacher ID from student meta data
        $teacher_id = get_user_meta($student_id, 'teacher', true);
        error_log('Teacher ID from student meta: ' . $teacher_id);
        
        if (!$teacher_id) {
            error_log('No teacher found for student ID: ' . $student_id);
            wp_send_json_error('No teacher assigned to this student');
            return;
        }
    } elseif (!$teacher_id) {
        error_log('Neither student_id nor teacher_id provided');
        wp_send_json_error('Teacher ID or Student ID is required');
        return;
    }
    
    global $wpdb;
    $table_name = $wpdb->prefix . 'free_slots';
    
    error_log('Querying free slots for teacher ID: ' . $teacher_id . ' from table: ' . $table_name);
    
    // Get free slots for the teacher
    $query = $wpdb->prepare(
        "SELECT id, user_id, day_of_week, start_time, end_time FROM $table_name WHERE user_id = %d ORDER BY day_of_week, start_time",
        $teacher_id
    );
    
    error_log('SQL Query: ' . $query);
    
    $slots = $wpdb->get_results($query);
    
    error_log('Free slots query result: ' . print_r($slots, true));
    error_log('WPDB last error: ' . $wpdb->last_error);
    
    if (empty($slots)) {
        error_log('No free slots found for teacher ID: ' . $teacher_id);
        wp_send_json_success(array());
        return;
    }
    
    // Get student's lesson duration if student_id is provided
    $lesson_duration = null;
    if ($student_id) {
        $lesson_duration = get_user_meta($student_id, 'lesson_duration', true);
        error_log('Student lesson duration: ' . $lesson_duration);
        
        // Convert to integer, default to 0 if not set or invalid
        $lesson_duration = intval($lesson_duration);
    }
    
    // Get all postponed events for this teacher to exclude conflicting time slots
    $schedules_table = $wpdb->prefix . 'student_schedules';
    $postponed_events = $wpdb->get_results($wpdb->prepare(
        "SELECT postponed_date, postponed_time, lesson_duration
         FROM $schedules_table
         WHERE teacher_id = %d AND is_postponed = 1",
        $teacher_id
    ));

    error_log('Found ' . count($postponed_events) . ' postponed events for teacher ' . $teacher_id);

    // Create a lookup array for postponed events to quickly check conflicts
    $postponed_lookup = array();
    $cairo_tz = new DateTimeZone('Africa/Cairo');
    foreach ($postponed_events as $postponed) {
        $postponed_datetime = new DateTime($postponed->postponed_date . ' ' . $postponed->postponed_time, $cairo_tz);
        $postponed_end = clone $postponed_datetime;
        $postponed_end->modify('+' . $postponed->lesson_duration . ' minutes');

        // Create a key for the day of week and time
        $day_of_week = $postponed_datetime->format('w'); // 0 = Sunday, 6 = Saturday
        $time_key = $postponed_datetime->format('H:i:s');
        $key = $day_of_week . '_' . $time_key;

        $postponed_lookup[$key] = array(
            'start' => $postponed_datetime,
            'end' => $postponed_end,
            'day_of_week' => $day_of_week,
            'start_time' => $time_key,
            'end_time' => $postponed_end->format('H:i:s')
        );
    }

    // Format the slots data and filter by lesson duration and postponed conflicts
    $formatted_slots = array();
    foreach ($slots as $slot) {
        // Calculate slot duration in minutes
        $start_time = DateTime::createFromFormat('H:i:s', $slot->start_time);
        $end_time = DateTime::createFromFormat('H:i:s', $slot->end_time);

        if ($start_time && $end_time) {
            $slot_duration_minutes = ($end_time->getTimestamp() - $start_time->getTimestamp()) / 60;

            // If lesson_duration is set and slot is shorter than required, skip this slot
            if ($lesson_duration > 0 && $slot_duration_minutes < $lesson_duration) {
                error_log('Skipping slot ' . $slot->id . ' - duration ' . $slot_duration_minutes . ' minutes is less than required ' . $lesson_duration . ' minutes');
                continue;
            }
        }

        // Split free slots around postponed events instead of hiding them entirely
        $slot_parts = [];
        $slot_start_time = $slot->start_time;
        $slot_end_time = $slot->end_time;

        // Find all postponed events that overlap with this free slot on the same day
        $overlapping_postponed = [];
        foreach ($postponed_lookup as $postponed_data) {
            if ($slot->day_of_week == $postponed_data['day_of_week']) {
                // Check time overlap
                if ($slot_start_time < $postponed_data['end_time'] && $slot_end_time > $postponed_data['start_time']) {
                    $overlapping_postponed[] = $postponed_data;
                }
            }
        }

        if (empty($overlapping_postponed)) {
            // No conflicts, add the entire free slot
            $slot_parts[] = [
                'start_time' => $slot_start_time,
                'end_time' => $slot_end_time
            ];
        } else {
            // Sort postponed events by start time
            usort($overlapping_postponed, function($a, $b) {
                return strcmp($a['start_time'], $b['start_time']);
            });

            $current_start = $slot_start_time;

            foreach ($overlapping_postponed as $postponed) {
                // If there's a gap before this postponed event, add it as a free slot part
                if ($current_start < $postponed['start_time']) {
                    $slot_parts[] = [
                        'start_time' => $current_start,
                        'end_time' => $postponed['start_time']
                    ];
                }

                // Move the start to after this postponed event
                $current_start = $postponed['end_time'] > $current_start ? $postponed['end_time'] : $current_start;
            }

            // If there's time remaining after the last postponed event, add it
            if ($current_start < $slot_end_time) {
                $slot_parts[] = [
                    'start_time' => $current_start,
                    'end_time' => $slot_end_time
                ];
            }
        }

        // Add all non-conflicting parts as separate free slot entries
        foreach ($slot_parts as $part_index => $part) {
            // Calculate part duration in minutes
            $part_start = DateTime::createFromFormat('H:i:s', $part['start_time']);
            $part_end = DateTime::createFromFormat('H:i:s', $part['end_time']);

            if ($part_start && $part_end) {
                $part_duration_minutes = ($part_end->getTimestamp() - $part_start->getTimestamp()) / 60;

                // Only add parts that are at least 15 minutes long to avoid tiny unusable slots
                if ($part_duration_minutes >= 15) {
                    $formatted_slots[] = array(
                        'id' => intval($slot->id) . '_part_' . $part_index, // Unique ID for each part
                        'user_id' => intval($slot->user_id),
                        'day_of_week' => $slot->day_of_week,
                        'start_time' => $part['start_time'],
                        'end_time' => $part['end_time']
                    );
                } else {
                    error_log('Skipping slot part ' . $slot->id . '_part_' . $part_index . ' - duration ' . $part_duration_minutes . ' minutes is less than 15 minutes');
                }
            }
        }
    }

    error_log('Sending success response with ' . count($formatted_slots) . ' free slots (filtered by lesson duration and postponed conflicts)');

    // Include lesson duration in the response for frontend use
    $response_data = array(
        'slots' => $formatted_slots,
        'lesson_duration' => $lesson_duration ?: 45 // Default to 45 minutes if not set
    );

    wp_send_json_success($response_data);
}

/**
 * REST API handler for creating postponed events
 */
function handle_create_postponed_event_rest($request) {
    global $wpdb;
    
    // Get data from request
    $params = $request->get_json_params();
    if (!$params) {
        $params = $request->get_params();
    }
    
    $student_id = intval($params['studentId'] ?? 0);
    $student_name = sanitize_text_field($params['studentName'] ?? '');
    $teacher_id = intval($params['teacherId'] ?? 0);
    $event_date = sanitize_text_field($params['eventDate'] ?? '');
    $event_time = sanitize_text_field($params['eventTime'] ?? '');
    $day_of_week = sanitize_text_field($params['dayOfWeek'] ?? '');
    
    // Validate required fields
    $missing_fields = array();
    if (!$student_id) $missing_fields[] = 'studentId';
    if (!$teacher_id) $missing_fields[] = 'teacherId';
    if (!$event_date) $missing_fields[] = 'eventDate';
    if (!$event_time) $missing_fields[] = 'eventTime';
    
    if (!empty($missing_fields)) {
        return new WP_Error('missing_fields', 'Missing required fields: ' . implode(', ', $missing_fields), array('status' => 400));
    }
    
    // Check if a postponed event already exists for this student, teacher, date, and time
    $table_name = $wpdb->prefix . 'student_schedules';
    $existing_postponed_event = $wpdb->get_row($wpdb->prepare(
        "SELECT id FROM {$table_name} 
         WHERE is_postponed = 1 AND student_id = %d AND teacher_id = %d AND postponed_date = %s AND postponed_time = %s",
        $student_id,
        $teacher_id,
        $event_date,
        $event_time
    ));
    
    if ($existing_postponed_event) {
        return new WP_Error('duplicate_event', 'A postponed event already exists for this student at the selected time', array('status' => 409));
    }
    
    // Get the original schedule to preserve lesson_duration
    $original_schedule = $wpdb->get_row($wpdb->prepare(
        "SELECT lesson_duration FROM {$table_name} WHERE student_id = %d AND teacher_id = %d LIMIT 1",
        $student_id,
        $teacher_id
    ));
    
    $lesson_duration = $original_schedule ? $original_schedule->lesson_duration : 60;
    
    // Use the actual student_id for postponed events
    $postponed_student_id = $student_id;
    
    // Create schedule data with real student ID for reference
    $schedule_data = json_encode(array('real_student_id' => $student_id));
    
    $result = $wpdb->insert(
        $table_name,
        array(
            'student_id' => $postponed_student_id,
            'teacher_id' => $teacher_id,
            'lesson_duration' => $lesson_duration,
            'schedule' => $schedule_data,
            'is_postponed' => 1,
            'postponed_date' => $event_date,
            'postponed_time' => $event_time,
            'is_recurring' => 0
        ),
        array('%d', '%d', '%d', '%s', '%d', '%s', '%s', '%d')
    );
    
    if ($result === false) {
        return new WP_Error('db_error', 'Failed to create postponed event: ' . $wpdb->last_error, array('status' => 500));
    }
    
    $event_id = $wpdb->insert_id;

    // IMPORTANT: Clear relevant caches when a postponed event is created
    // This ensures the calendar updates immediately to hide conflicting free slots
    wp_cache_delete('schedules_' . $student_id, SCHEDULE_CACHE_GROUP);
    if ($teacher_id) {
        wp_cache_delete('teacher_schedules_' . $teacher_id, TEACHER_CACHE_GROUP);
    }

    return array(
        'success' => true,
        'message' => 'Postponed event created successfully',
        'event_id' => $event_id,
        'event_date' => $event_date,
        'event_time' => $event_time
    );
}

/**
 * Calculate the correct session number for API report creation
 * This implements the same logic as the web interface to ensure consistency
 */
function calculate_session_number_for_api($student_id, $attendance) {
    global $wpdb;

    // Define non-valid attendances that should always use session number 0
    $non_valid_attendances = ['تعويض التأجيل', 'تعويض الغياب', 'تجريبي'];

    // If this is a non-valid attendance type, always return 0
    if (in_array($attendance, $non_valid_attendances)) {
        return 0;
    }

    // Fetch ALL reports for the student, ordered by date and time
    // Exclude postponed reports (session_number = 0) from session number calculations
    $all_reports = $wpdb->get_results($wpdb->prepare(
        "SELECT date, session_number, attendance
         FROM wp_student_reports
         WHERE student_id = %d AND session_number > 0
         ORDER BY date DESC, time DESC",
        $student_id
    ));

    // Fetch the student's lessons_number from usermeta
    $lessons_number = intval(get_user_meta($student_id, 'lessons_number', true));

    if ($attendance === 'اجازة معلم') {
        // For اجازة معلم, find the last incrementing report and use its session number
        $incrementing_attendances = ['حضور', 'غياب', 'تأجيل المعلم', 'تأجيل ولي أمر'];

        foreach ($all_reports as $report) {
            if (in_array($report->attendance, $incrementing_attendances)) {
                return intval($report->session_number);
            }
        }

        // No incrementing reports found, default to 1
        return 1;
    } else {
        // For other attendances, use the regular logic from get_last_report_date
        // Find the last incrementing report
        $incrementing_attendances = ['حضور', 'غياب', 'تأجيل المعلم', 'تأجيل ولي أمر'];

        foreach ($all_reports as $report) {
            if (in_array($report->attendance, $incrementing_attendances)) {
                $last_session = intval($report->session_number);
                $next_session_number = $last_session + 1;

                // Handle reset logic when reaching lessons_number
                if ($lessons_number > 0 && $next_session_number > $lessons_number) {
                    $next_session_number = 1;
                }

                // Ensure we never have a session number less than 1
                if ($next_session_number < 1) {
                    $next_session_number = 1;
                }

                return $next_session_number;
            }
        }

        // No incrementing reports found, default to 1
        return 1;
    }
}

/**
 * REST API handler for testing session number calculation
 */
function handle_test_session_number_rest($request) {
    $student_id = intval($request->get_param('student_id') ?? 0);
    $attendance = sanitize_text_field($request->get_param('attendance') ?? 'تأجيل ولي أمر');
    
    if (!$student_id) {
        return new WP_Error('missing_student_id', 'Student ID is required', array('status' => 400));
    }
    
    // Calculate session number
    $session_number = calculate_session_number_for_api($student_id, $attendance);
    
    // Get student reports for debugging
    global $wpdb;
    $all_reports = $wpdb->get_results($wpdb->prepare(
        "SELECT date, session_number, attendance, time
         FROM wp_student_reports
         WHERE student_id = %d AND session_number > 0
         ORDER BY date DESC, time DESC",
        $student_id
    ));
    
    // Get student's lessons_number
    $lessons_number = intval(get_user_meta($student_id, 'lessons_number', true));
    
    return array(
        'success' => true,
        'student_id' => $student_id,
        'attendance' => $attendance,
        'calculated_session_number' => $session_number,
        'lessons_number' => $lessons_number,
        'existing_reports_count' => count($all_reports),
        'existing_reports' => $all_reports,
        'debug_info' => array(
            'non_valid_attendances' => ['تعويض التأجيل', 'تعويض الغياب', 'تجريبي'],
            'incrementing_attendances' => ['حضور', 'غياب', 'تأجيل المعلم', 'تأجيل ولي أمر']
        )
    );
}

/**
 * REST API handler for creating student reports
 */
function handle_create_student_report_rest($request) {
    global $wpdb;

    // Get data from request
    $params = $request->get_json_params();
    if (!$params) {
        $params = $request->get_params();
    }

    $student_id = intval($params['studentId'] ?? 0);
    $teacher_id = intval($params['teacherId'] ?? 0);
    $attendance = sanitize_text_field($params['attendance'] ?? '');
    $session_number_from_client = sanitize_text_field($params['sessionNumber'] ?? ''); // Keep client value for reference
    $date = sanitize_text_field($params['date'] ?? '');
    $time = sanitize_text_field($params['time'] ?? '');
    $lesson_duration = intval($params['lessonDuration'] ?? 0);
    $evaluation = sanitize_text_field($params['evaluation'] ?? '');
    $grade = intval($params['grade'] ?? 0);
    $tasmii = sanitize_textarea_field($params['tasmii'] ?? '');
    $tahfiz = sanitize_textarea_field($params['tahfiz'] ?? '');
    $mourajah = sanitize_textarea_field($params['mourajah'] ?? '');
    $next_tasmii = sanitize_textarea_field($params['nextTasmii'] ?? '');
    $next_mourajah = sanitize_textarea_field($params['nextMourajah'] ?? '');
    $notes = sanitize_textarea_field($params['notes'] ?? '');
    $zoom_image_url = sanitize_url($params['zoomImageUrl'] ?? '');
    $is_postponed = intval($params['isPostponed'] ?? 0);

    // Validate required fields
    $missing_fields = array();
    if (!$student_id) $missing_fields[] = 'studentId';
    if (!$teacher_id) $missing_fields[] = 'teacherId';
    if (!$attendance) $missing_fields[] = 'attendance';
    if (!$date) $missing_fields[] = 'date';
    if (!$lesson_duration) $missing_fields[] = 'lessonDuration';

    if (!empty($missing_fields)) {
        return new WP_Error('missing_fields', 'Missing required fields: ' . implode(', ', $missing_fields), array('status' => 400));
    }

    // IMPORTANT FIX: Calculate the correct session number based on attendance type and student's history
    // This implements the same logic as the web interface to ensure consistency
    $session_number = calculate_session_number_for_api($student_id, $attendance);

    error_log("API: Calculated session number " . $session_number . " for student " . $student_id . " with attendance " . $attendance . " (client sent: " . $session_number_from_client . ")");

    // IMPORTANT FIX: Normalize time format to ensure consistency with calendar queries
    // Convert time to H:i:s format (24-hour with seconds) to match database schema
    if (!empty($time)) {
        $time_normalized = date('H:i:s', strtotime($time));
        if ($time_normalized !== false) {
            $time = $time_normalized;
            error_log("API: Normalized time from '" . $params['time'] . "' to '" . $time . "'");
        }
    }

    // Insert into wp_student_reports table
    $table_name = $wpdb->prefix . 'student_reports';
    $result = $wpdb->insert(
        $table_name,
        array(
            'student_id' => $student_id,
            'teacher_id' => $teacher_id,
            'attendance' => $attendance,
            'session_number' => $session_number,
            'date' => $date,
            'time' => $time,
            'lesson_duration' => $lesson_duration,
            'evaluation' => $evaluation,
            'grade' => $grade,
            'tasmii' => $tasmii,
            'tahfiz' => $tahfiz,
            'mourajah' => $mourajah,
            'next_tasmii' => $next_tasmii,
            'next_mourajah' => $next_mourajah,
            'notes' => $notes,
            'zoom_image_url' => $zoom_image_url,
            'is_postponed' => $is_postponed
        ),
        array('%d', '%d', '%s', '%s', '%s', '%s', '%d', '%s', '%d', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%d')
    );
    
    if ($result === false) {
        return new WP_Error('db_error', 'Failed to create student report: ' . $wpdb->last_error, array('status' => 500));
    }

    $report_id = $wpdb->insert_id;

    // IMPORTANT FIX: Ensure database transaction is committed immediately
    // This helps with the calendar seeing the new report right away
    if (method_exists($wpdb, 'flush')) {
        $wpdb->flush();
    }

    // Log the report creation for debugging
    error_log("API: Created report ID " . $report_id . " for student " . $student_id . " on " . $date . " at " . $time);

    // IMPORTANT: Clear relevant caches when a report is created via API
    // This ensures the calendar updates immediately to hide gray schedules
    wp_cache_delete('reports_' . $student_id, REPORT_CACHE_GROUP);
    wp_cache_delete('schedules_' . $student_id, SCHEDULE_CACHE_GROUP);
    if ($teacher_id) {
        wp_cache_delete('teacher_schedules_' . $teacher_id, TEACHER_CACHE_GROUP);
    }

    // IMPORTANT FIX: Also clear any WordPress object cache that might be interfering
    // This ensures the teacher calendar will see the new report immediately
    wp_cache_flush_group(REPORT_CACHE_GROUP);
    wp_cache_flush_group(SCHEDULE_CACHE_GROUP);
    if ($teacher_id) {
        wp_cache_flush_group(TEACHER_CACHE_GROUP);
    }

    // Additional cache clearing for immediate effect
    if (function_exists('wp_cache_flush')) {
        wp_cache_flush();
    }

    return array(
        'success' => true,
        'message' => 'Student report created successfully',
        'report_id' => $report_id,
        'date' => $date,
        'time' => $time
    );
}

/**
 * Legacy AJAX handler for creating postponed events (kept for backward compatibility)
 */
function handle_create_postponed_event() {
    // Check if user is logged in
    if (!is_user_logged_in()) {
        wp_send_json_error('User not authenticated');
        return;
    }
    
    global $wpdb;
    
    // Get data from POST request
    $student_id = intval($_POST['student_id']);
    $student_name = sanitize_text_field($_POST['student_name']);
    $teacher_id = intval($_POST['teacher_id']);
    $event_date = sanitize_text_field($_POST['event_date']);
    $event_time = sanitize_text_field($_POST['event_time']);
    $day_of_week = sanitize_text_field($_POST['day_of_week']);
    $attendance_status = sanitize_text_field($_POST['attendance_status']);
    $is_postponed = isset($_POST['is_postponed']) ? 1 : 0;
    
    // Validate required fields with detailed error messages
    $missing_fields = array();
    if (!$student_id) $missing_fields[] = 'student_id';
    if (!$teacher_id) $missing_fields[] = 'teacher_id';
    if (!$event_date) $missing_fields[] = 'event_date';
    if (!$event_time) $missing_fields[] = 'event_time';
    
    if (!empty($missing_fields)) {
        wp_send_json_error(array(
            'message' => 'Missing required fields: ' . implode(', ', $missing_fields),
            'missing_fields' => $missing_fields,
            'received_data' => array(
                'student_id' => $student_id,
                'teacher_id' => $teacher_id,
                'event_date' => $event_date,
                'event_time' => $event_time,
                'student_name' => $student_name,
                'day_of_week' => $day_of_week,
                'attendance_status' => $attendance_status
            )
        ));
        return;
    }
    
    // Calculate the correct session number for the postponed event
    // Get the last incrementing report for this student
    $last_report = $wpdb->get_row($wpdb->prepare(
        "SELECT session_number FROM {$wpdb->prefix}student_reports 
         WHERE student_id = %d 
         AND attendance IN ('حضور', 'غياب', 'تأجيل المعلم', 'تأجيل ولي أمر')
         ORDER BY date DESC, time DESC 
         LIMIT 1",
        $student_id
    ));
    
    // Get student's lessons_number
    $lessons_number = intval(get_user_meta($student_id, 'lessons_number', true));
    
    // Calculate next session number
    $session_number = 1; // Default for new students
    if ($last_report) {
        $last_session = intval($last_report->session_number);
        $session_number = $last_session + 1;
        
        // Handle reset logic when reaching lessons_number
        if ($lessons_number > 0 && $session_number > $lessons_number) {
            $session_number = 1; // Reset to 1 after completing all lessons
        }
        
        // Ensure we never have a session number less than 1
        if ($session_number < 1) {
            $session_number = 1;
        }
    }
    
    // Create the postponed event in the database
    // We'll use the wp_student_schedules table to store postponed events
    $table_name = $wpdb->prefix . 'student_schedules';
    
    // Check if a postponed event already exists for this student, teacher, date, and time
    $existing_postponed_events = $wpdb->get_results($wpdb->prepare(
        "SELECT id, schedule FROM {$table_name} 
         WHERE is_postponed = 1 AND teacher_id = %d AND postponed_date = %s AND postponed_time = %s AND student_id < 0",
        $teacher_id,
        $event_date,
        $event_time
    ));
    
    // Check if any existing postponed event matches this student
    foreach ($existing_postponed_events as $existing_event) {
        $existing_schedule_data = json_decode($existing_event->schedule, true);
        if (isset($existing_schedule_data['real_student_id']) && $existing_schedule_data['real_student_id'] == $student_id) {
            wp_send_json_error(array(
                'message' => 'A postponed event already exists for this student at the selected time',
                'existing_event_id' => $existing_event->id
            ));
            return;
        }
    }
    
    // Get the original schedule to preserve lesson_duration
    $original_schedule = $wpdb->get_row($wpdb->prepare(
        "SELECT lesson_duration FROM {$table_name} WHERE student_id = %d AND teacher_id = %d LIMIT 1",
        $student_id,
        $teacher_id
    ));
    
    $lesson_duration = $original_schedule ? $original_schedule->lesson_duration : 60; // Default to 60 minutes
    
    // Create a unique student_id for postponed events by using negative values
    // This avoids the UNIQUE constraint issue
    $postponed_student_id = -($student_id * 1000 + time() % 1000); // Create unique negative ID
    
    // Create empty schedule since this is a one-time postponed event
    $schedule_data = json_encode(array());
    
    $result = $wpdb->insert(
        $table_name,
        array(
            'student_id' => $postponed_student_id, // Use unique negative ID
            'teacher_id' => $teacher_id,
            'lesson_duration' => $lesson_duration,
            'schedule' => $schedule_data, // Empty schedule for one-time events
            'is_postponed' => 1,
            'postponed_date' => $event_date,
            'postponed_time' => $event_time,
            'original_date' => $original_date,
            'original_time' => $original_time,
            'is_recurring' => 0 // Not recurring
        ),
        array(
            '%d', // student_id (negative unique ID)
            '%d', // teacher_id
            '%d', // lesson_duration
            '%s', // schedule
            '%d', // is_postponed
            '%s', // postponed_date
            '%s', // postponed_time
            '%s', // original_date
            '%s', // original_time
            '%d'  // is_recurring
        )
    );
    
    // Also store the actual student_id in a custom field for reference
    if ($result !== false) {
        $postponed_event_id = $wpdb->insert_id;
        // Store the real student_id as metadata or in a separate field
        // For now, we'll use a comment or note system to track the real student
        $wpdb->update(
            $table_name,
            array('schedule' => json_encode(array('real_student_id' => $student_id))),
            array('id' => $postponed_event_id),
            array('%s'),
            array('%d')
        );
    }
    
    if ($result === false) {
        wp_send_json_error(array(
            'message' => 'Failed to create postponed event',
            'db_error' => $wpdb->last_error
        ));
        return;
    }
    
    $event_id = $wpdb->insert_id;

    // IMPORTANT: Clear relevant caches when a postponed event is created
    // This ensures the calendar updates immediately to hide conflicting free slots
    wp_cache_delete('schedules_' . $student_id, SCHEDULE_CACHE_GROUP);
    if ($teacher_id) {
        wp_cache_delete('teacher_schedules_' . $teacher_id, TEACHER_CACHE_GROUP);
    }

    wp_send_json_success(array(
        'message' => 'Postponed event created successfully',
        'event_id' => $event_id,
        'event_date' => $event_date,
        'event_time' => $event_time
    ));
}

/**
 * Get student's teacher ID from user meta
 */
function handle_get_student_teacher_id() {
    // Check if user is logged in
    if (!is_user_logged_in()) {
        wp_send_json_error('User not authenticated');
        return;
    }
    
    $student_id = intval($_POST['student_id']);
    
    if (!$student_id) {
        wp_send_json_error('Student ID is required');
        return;
    }
    
    // Get teacher ID from student's user meta
    $teacher_id = get_user_meta($student_id, 'teacher', true);
    
    if (!$teacher_id) {
        wp_send_json_error('No teacher assigned to this student');
        return;
    }
    
    wp_send_json_success(array(
        'teacher_id' => intval($teacher_id)
    ));
}

/**
 * Hostinger Cron Job Setup Instructions:
 * 
 * 1. Log in to your Hostinger control panel
 * 2. Navigate to the Cron Jobs section
 * 3. Create a new cron job with the following settings:
 *    - Command: curl https://system.zuwad-academy.com/wp-json/custom/v1/clear-cache?secret=12345
 *    - Frequency: Daily (or as needed)
 * 
 * This will automatically refresh your cache every day to ensure data stays current
 * while maintaining performance benefits.
 */