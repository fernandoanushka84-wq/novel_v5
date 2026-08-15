DROP DATABASE IF EXISTS novel_app_db;
CREATE DATABASE novel_app_db;
USE novel_app_db;

CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    topic_count INT NOT NULL DEFAULT 0,
    tab_group ENUM('discover', 'explore') NOT NULL,
    sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE books (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(120) NOT NULL,
    description TEXT NOT NULL,
    cover_path VARCHAR(255) NOT NULL DEFAULT '',
    accent_hex VARCHAR(20) NOT NULL DEFAULT '#808080',
    section_name ENUM('featured', 'recently_updated', 'recently_completed') NOT NULL,
    status_text VARCHAR(60) NOT NULL DEFAULT '',
    rating DECIMAL(3,1) NOT NULL DEFAULT 0,
    genre VARCHAR(80) NOT NULL DEFAULT '',
    primary_genre VARCHAR(80) NOT NULL DEFAULT '',
    secondary_genre VARCHAR(80) NOT NULL DEFAULT '',
    is_completed TINYINT(1) NOT NULL DEFAULT 0,
    cta_label VARCHAR(60) NOT NULL DEFAULT 'Read now',
    sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE library_entries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    reading_status VARCHAR(60) NOT NULL,
    updated_text VARCHAR(60) NOT NULL,
    chapters INT NOT NULL DEFAULT 0,
    primary_genre VARCHAR(80) NOT NULL,
    secondary_genre VARCHAR(80) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_library_book FOREIGN KEY (book_id) REFERENCES books(id)
);

CREATE TABLE write_screen (
    id INT AUTO_INCREMENT PRIMARY KEY,
    manage_tabs VARCHAR(255) NOT NULL,
    story_tabs VARCHAR(255) NOT NULL,
    filter_label VARCHAR(100) NOT NULL,
    sort_label VARCHAR(100) NOT NULL,
    empty_title VARCHAR(255) NOT NULL,
    empty_cta VARCHAR(100) NOT NULL
);

CREATE TABLE notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tab_name VARCHAR(40) NOT NULL,
    title VARCHAR(80) NOT NULL,
    message TEXT NOT NULL,
    created_at VARCHAR(80) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE menu_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    section_name VARCHAR(80) NOT NULL,
    section_order INT NOT NULL DEFAULT 0,
    label VARCHAR(120) NOT NULL,
    icon_name VARCHAR(60) NOT NULL,
    route_name VARCHAR(60) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE profiles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    display_name VARCHAR(120) NOT NULL,
    username VARCHAR(120) NOT NULL,
    following INT NOT NULL DEFAULT 0,
    followers INT NOT NULL DEFAULT 0,
    blocked INT NOT NULL DEFAULT 0,
    chapters_read INT NOT NULL DEFAULT 0,
    social_karma INT NOT NULL DEFAULT 0,
    day_streak INT NOT NULL DEFAULT 0
);

CREATE TABLE reading_lists (
    id INT AUTO_INCREMENT PRIMARY KEY,
    profile_id INT NOT NULL,
    name VARCHAR(120) NOT NULL,
    story_count INT NOT NULL DEFAULT 0,
    cover_path VARCHAR(255) NOT NULL DEFAULT '',
    sort_order INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_reading_lists_profile FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

CREATE TABLE achievements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    group_name VARCHAR(120) NOT NULL,
    group_order INT NOT NULL DEFAULT 0,
    title VARCHAR(120) NOT NULL,
    subtitle VARCHAR(255) NOT NULL,
    progress_label VARCHAR(255) NOT NULL,
    badge_value VARCHAR(40) NOT NULL,
    style VARCHAR(40) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0
);

INSERT INTO categories (name, topic_count, tab_group, sort_order) VALUES
('New', 0, 'discover', 1),
('Popular', 0, 'discover', 2),
('Fanfiction', 0, 'discover', 3),
('Newsfeed', 0, 'discover', 4),
('Fanfiction', 100, 'explore', 1),
('Fantasy', 31, 'explore', 2),
('Poetry', 14, 'explore', 3),
('Adventure', 35, 'explore', 4),
('Horror', 29, 'explore', 5),
('Thriller', 35, 'explore', 6),
('Young Adult', 0, 'explore', 7),
('LGBTQ+', 0, 'explore', 8),
('Literary Fiction', 0, 'explore', 9),
('Historical Fiction', 0, 'explore', 10),
('Erotica', 32, 'explore', 11),
('Mystery', 32, 'explore', 12),
('SciFi', 31, 'explore', 13),
('Humor', 24, 'explore', 14);

INSERT INTO books (title, author, description, cover_path, accent_hex, section_name, status_text, rating, genre, cta_label, sort_order) VALUES
('Reclaimed by the Alpha: The Alpha''s Hidden Heir', 'L. Cross', 'Six years ago, Nick Blackwood broke my heart on Christmas morning when he believed a lie that destroyed us both. I disappeared, rebuilt my life, and raised his daughter alone.', 'story_card_images/006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg', '#A06054', 'featured', '2hr ago', 5.0, 'Romance', 'Read now', 1),
('Reclaimed by the Alpha', 'L. Cross', 'Featured in recently updated.', 'story_card_images/006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg', '#A06054', 'recently_updated', '2hr ago', 5.0, 'Romance', 'Read now', 1),
('The Unexpected Prisoner', 'SpicySammy', 'Fantasy romance story.', 'story_card_images/04d68518-aafb-497e-995e-10bc6e4bef90.jpg', '#7661A8', 'recently_updated', '1hr ago', 4.8, 'Fantasy', 'Read now', 2),
('James', 'Tamaska Tyne', 'Forest wolves chronicles.', 'story_card_images/19eb26e8-6ee4-4010-8848-8f5779f602dd.jpg', '#A98A52', 'recently_updated', '3hr ago', 4.7, 'Fantasy', 'Read now', 3),
('Soul Rebirth', 'Inferno', 'Infernal rebirth fantasy.', 'story_card_images/0d88ca6e-bdb9-4d45-b7f4-013f0ef843e5.jpg', '#5B5AA8', 'recently_updated', '5hr ago', 4.6, 'Fantasy', 'Read now', 4),
('The Silence of Shadows', 'Kurt Brunnhuber', 'Dark fantasy complete novel.', 'story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg', '#674C6B', 'recently_completed', 'Completed', 4.8, 'Fantasy', 'Read now', 5),
('What Now?', 'Angela Lawece', 'Emotional drama complete novel.', 'story_card_images/6a5c2a85-2d8c-498d-9153-1d72ec4005e4.jpg', '#C69595', 'recently_completed', 'Completed', 4.5, 'Drama', 'Read now', 6),
('Perpromenos', 'Koyar Kora', 'Mythic green cover drama.', 'story_card_images/7d7d5cc8-5b0a-4821-9e57-3f58c36998b0.jpg', '#8E9877', 'recently_completed', 'Completed', 4.4, 'Literary Fiction', 'Read now', 7),
('Owned by the Lycan King (18+)', 'E.F BONI', 'Currently in user library.', 'story_card_images/8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg', '#8B523C', 'recently_completed', 'Completed', 4.8, 'Romance', 'Read now', 8),
('Lune', 'Angela Lawece', 'Moonlit fantasy sci-fi.', 'story_card_images/9e84fd30-5477-45f2-8c48-5c290f275856.jpg', '#66738D', 'recently_completed', '2wk ago', 4.2, 'Fantasy', 'Read now', 9);

INSERT INTO library_entries (book_id, reading_status, updated_text, chapters, primary_genre, secondary_genre, sort_order) VALUES
(8, 'Completed', '31 Chapters', 31, 'Romance', 'Erotica', 1),
(9, '2wk ago', '4 Chapters', 4, 'Fantasy', 'SciFi', 2);

INSERT INTO write_screen (manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta) VALUES
('Manage Stories,Analytics', 'Submitted,Drafts', 'All stories', 'Recently Updated', 'You haven''t submitted any story yet', 'Submit Stories');

INSERT INTO notifications (tab_name, title, message, created_at, sort_order) VALUES
('System', 'Inkitt', 'Earn some karma. Help this author today by reading their story!', 'Tue Apr 19:11', 1);

INSERT INTO menu_items (section_name, section_order, label, icon_name, route_name, sort_order) VALUES
('Profile', 1, 'My Profile', 'person', 'profile', 1),
('Profile', 1, 'Reading Stats', 'bar_chart', 'stats', 2),
('Community', 2, 'Groups', 'groups', 'groups', 1),
('Support', 3, 'Help Center', 'help', 'help', 1),
('Support', 3, 'Contact Us', 'chat', 'contact', 2),
('Settings', 4, 'Notifications', 'notifications', 'notifications', 1),
('Settings', 4, 'App Language', 'language', 'language', 2),
('Settings', 4, 'Favourite Genres', 'favorite', 'genres', 3),
('Settings', 4, 'AI Content Review', 'auto_awesome', 'ai-review', 4),
('Settings', 4, 'Content Warnings', 'warning', 'warnings', 5),
('Legal', 5, 'Manage Cookie Preferences', 'cookie', 'cookies', 1),
('Legal', 5, 'Terms of Service', 'description', 'terms', 2),
('Legal', 5, 'Privacy Policy', 'lock', 'privacy', 3),
('Change Accounts', 6, 'Sign Out', 'logout', 'logout', 1);

INSERT INTO profiles (display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak) VALUES
('Sghj', '@sghj', 1, 0, 0, 0, 0, 0);

INSERT INTO reading_lists (profile_id, name, story_count, cover_path, sort_order) VALUES
(1, 'Currently Reading', 2, 'story_card_images/8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg', 1),
(1, 'Archived / Finished Books', 0, 'story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg', 2);

INSERT INTO achievements (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order) VALUES
('Lifetime Reviews Given', 1, 'Reviewer-in-Training', '0/1 Reviews Left', '0/1 Reviews Left', '1', 'silver', 1),
('Lifetime Reviews Given', 1, 'Community Voice', '0/2 Reviews Left', '0/2 Reviews Left', '2', 'silver', 2),
('Lifetime Reviews Given', 1, 'Story Critic', '0/3 Reviews Left', '0/3 Reviews Left', '3', 'silver', 3),
('Lifetime Words Published', 2, 'Ink Sprout', '0/1000 Words Published', '0/1000 Words Published', '1000', 'dark', 1),
('Lifetime Words Published', 2, 'Wordsmith', '0/5000 Words Published', '0/5000 Words Published', '5000', 'dark', 2),
('Lifetime Words Published', 2, 'Pen Prodigy', '0/10000 Words Published', '0/10000 Words Published', '10000', 'dark', 3),
('Lifetime Reading', 3, 'Page Flipper', '0/2 Chapters Read', '0/2 Chapters Read', '2', 'ink', 1),
('Lifetime Reading', 3, 'Book Explorer', '0/5 Chapters Read', '0/5 Chapters Read', '5', 'ink', 2),
('Lifetime Reading', 3, 'Reading Enthusiast', '0/10 Chapters Read', '0/10 Chapters Read', '10', 'ink', 3);