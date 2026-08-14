-- Delete all seeded mock device users
DELETE FROM users 
WHERE username IN (
    'att_device_main', 
    'att_device_back', 
    'att_camera_hall', 
    'wh_scanner_in', 
    'wh_scanner_out', 
    'wh_tablet_mgr', 
    'tech_pad_a', 
    'tech_pad_b', 
    'tech_app_user1'
);

-- Delete corresponding refresh token sessions
DELETE FROM refresh_tokens 
WHERE token_hash IN (
    'simulated_hash_1', 
    'simulated_hash_2', 
    'simulated_hash_4', 
    'simulated_hash_5', 
    'simulated_hash_7', 
    'simulated_hash_9'
);
