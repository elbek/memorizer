-- Add Daily system pool for all existing users who don't have one yet
INSERT INTO pools (user_id, name, is_system)
SELECT id, 'Daily', 1 FROM users
WHERE id NOT IN (SELECT user_id FROM pools WHERE name = 'Daily');
