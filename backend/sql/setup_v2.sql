-- Novel App Database Schema v2 with Enhanced Structure

-- Drop existing database to start fresh
DROP DATABASE IF EXISTS novel_app_db;
CREATE DATABASE novel_app_db;
USE novel_app_db;

-- ============================================
-- Users & Profiles (MUST BE FIRST)
-- ============================================
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255),
    display_name VARCHAR(100),
    bio TEXT,
    avatar_path VARCHAR(255),
    is_author BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (username),
    INDEX (created_at)
);

CREATE TABLE user_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    followers INT DEFAULT 0,
    following INT DEFAULT 0,
    blocked INT DEFAULT 0,
    chapters_read INT DEFAULT 0,
    social_karma INT DEFAULT 0,
    day_streak INT DEFAULT 0,
    KEY fk_user_stats_user (user_id)
);

-- ============================================
-- Categories & Genres
-- ============================================
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon_name VARCHAR(50),
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (display_order)
);

CREATE TABLE genres (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    color_hex VARCHAR(7),
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (display_order)
);

-- ============================================
-- Stories & Books
-- ============================================
CREATE TABLE stories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    author_id INT NOT NULL,
    description TEXT NOT NULL,
    cover_path VARCHAR(255),
    accent_hex VARCHAR(7) DEFAULT '#8429D2',
    primary_genre_id INT,
    secondary_genre_id INT,
    category_id INT,
    status ENUM('ONGOING', 'COMPLETED', 'HIATUS', 'CANCELLED') DEFAULT 'ONGOING',
    rating DECIMAL(3, 2) DEFAULT 0.0,
    rating_count INT DEFAULT 0,
    views INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (primary_genre_id) REFERENCES genres(id),
    FOREIGN KEY (secondary_genre_id) REFERENCES genres(id),
    FOREIGN KEY (category_id) REFERENCES categories(id),
    INDEX (status),
    INDEX (category_id),
    INDEX (author_id),
    INDEX (created_at)
);

CREATE TABLE chapters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    story_id INT NOT NULL,
    chapter_number INT NOT NULL,
    title VARCHAR(255),
    content LONGTEXT NOT NULL,
    word_count INT DEFAULT 0,
    published_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
    UNIQUE KEY unique_chapter (story_id, chapter_number),
    INDEX (story_id),
    INDEX (published_at)
);

-- ============================================
-- User Library & Reading Status
-- ============================================
CREATE TABLE library_entries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    story_id INT NOT NULL,
    reading_status ENUM('READING', 'COMPLETED', 'ABANDONED', 'PLANNING') DEFAULT 'READING',
    last_read_chapter INT DEFAULT 0,
    progress_percent INT DEFAULT 0,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
    UNIQUE KEY unique_library_entry (user_id, story_id),
    INDEX (user_id),
    INDEX (reading_status)
);

-- ============================================
-- Reading Lists
-- ============================================
CREATE TABLE reading_lists (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    cover_path VARCHAR(255),
    story_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX (user_id)
);

CREATE TABLE reading_list_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reading_list_id INT NOT NULL,
    story_id INT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (reading_list_id) REFERENCES reading_lists(id) ON DELETE CASCADE,
    FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
    UNIQUE KEY unique_list_item (reading_list_id, story_id)
);

-- ============================================
-- Achievements & Badges
-- ============================================
CREATE TABLE achievement_groups (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE achievements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    group_id INT NOT NULL,
    title VARCHAR(100) NOT NULL,
    badge_value VARCHAR(10),
    style ENUM('gold', 'silver', 'dark', 'black') DEFAULT 'black',
    progress_label VARCHAR(100),
    display_order INT DEFAULT 0,
    FOREIGN KEY (group_id) REFERENCES achievement_groups(id) ON DELETE CASCADE
);

CREATE TABLE user_achievements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    achievement_id INT NOT NULL,
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (achievement_id) REFERENCES achievements(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_achievement (user_id, achievement_id)
);

-- ============================================
-- Notifications
-- ============================================
CREATE TABLE notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    message VARCHAR(255) NOT NULL,
    notification_type ENUM('STORY', 'COMMUNITY', 'SYSTEM') DEFAULT 'SYSTEM',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX (user_id),
    INDEX (created_at)
);

-- ============================================
-- Menu & CMS
-- ============================================
CREATE TABLE menu_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    icon VARCHAR(50),
    route VARCHAR(100),
    menu_section_id INT,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE menu_sections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- Seed Data
-- ============================================

-- Categories (matching Discover screen sections)
INSERT INTO categories (name, slug, description, icon_name, display_order) VALUES
('New', 'new', 'Recently published stories', 'auto_stories', 1),
('Popular', 'popular', 'Most read and liked stories', 'trending_up', 2),
('Fanfiction', 'fanfiction', 'Fan-created stories', 'favorite', 3),
('Newsfeed', 'newsfeed', 'Trending and community picks', 'feed', 4);

-- Genres (with colors matching the screenshot palette)
INSERT INTO genres (name, slug, description, color_hex, display_order) VALUES
('Romance', 'romance', 'Love stories and relationships', '#E86C9F', 1),
('Fantasy', 'fantasy', 'Magic, quests, and fantasy worlds', '#7B68EE', 2),
('Drama', 'drama', 'Emotional and dramatic narratives', '#DC143C', 3),
('Erotica', 'erotica', 'Adult content and relationships', '#FF69B4', 4),
('Young Adult', 'young-adult', 'Stories for teen and young audiences', '#FFB6C1', 5),
('Mystery', 'mystery', 'Suspense, secrets, and investigations', '#2F4F4F', 6),
('Horror', 'horror', 'Scary and supernatural stories', '#8B0000', 7),
('Science Fiction', 'sci-fi', 'Future tech and space adventures', '#00CED1', 8),
('Historical Fiction', 'historical-fiction', 'Stories set in past eras', '#8B4513', 9),
('Adventure', 'adventure', 'Action-packed journeys', '#FF8C00', 10),
('LGBTQ+', 'lgbtq', 'LGBTQ+ centered narratives', '#FF00FF', 11),
('Poetry', 'poetry', 'Poetic works and verses', '#DAA520', 12);

-- Default User (for seed stories)
INSERT INTO users (username, email, display_name, bio, is_author) VALUES
('system_author', 'system@inkitt.local', 'Inkitt', 'System-generated content', TRUE);

INSERT INTO user_stats (user_id, followers, following, blocked, chapters_read, social_karma, day_streak) VALUES
(1, 1000, 50, 0, 500, 1000, 30);

-- Sample Stories for various genres (from screenshots)
INSERT INTO stories (title, slug, author_id, description, cover_path, accent_hex, primary_genre_id, secondary_genre_id, category_id, status, rating, rating_count, views) VALUES
('Odio público, juego privado', 'odio-publico-juego-privado', 1, 'En el mundo de las carreras, Babe y Charlie son rivales públicos que parecen odiarse con todo su ser. Sin embargo, en privado comparten un secret...', 'story_card_images/006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg', '#DC143C', 3, 1, 1, 'COMPLETED', 4.8, 2305, 50000),
('Echoes of Us: Second Chance Romance 2026', 'echoes-of-us-2026', 1, 'A tale of second chances and unexpected encounters in modern times.', 'story_card_images/0aaa5ea7-670f-4995-8378-474c09b319b2.jpg', '#E86C9F', 1, 4, 1, 'ONGOING', 4.5, 1800, 35000),
('Scent of Another Alpha', 'scent-of-another-alpha', 1, 'He rejected the mate bond to marry the right omega. Six years later, she''s built an empire from the wreckage — and the scent of her new alpha is...', 'story_card_images/4a4f19a1-b096-4613-b635-f71e311481d1.jpg', '#8B4513', 1, 4, 1, 'ONGOING', 5.0, 3200, 75000),
('Conquering My Stepmother & Building My Life', 'conquering-stepmother', 1, 'Kai died an average man and woke up in a brutal world of Cultivators and Immortals. He has no talent, no money, and no background...', 'story_card_images/5ba33f5b-f733-4dd3-a3d8-ad66dacfb093.jpg', '#7B68EE', 2, 5, 1, 'ONGOING', 4.6, 2100, 55000),
('Say You Are Mine', 'say-you-are-mine', 1, 'One night stand. No names. No rules. No regrets. It was supposed to stay that way...', 'story_card_images/a5f489f6-2a42-43c0-a190-2da06adfebf8.jpg', '#E86C9F', 1, 4, 2, 'COMPLETED', 4.9, 2900, 68000),
('The Myth of Sisyphus and his Heirs Vol.3', 'the-myth-of-sisyphus-vol3', 1, 'An unfillable, eternal loneliness...I am a lonely orphan of heart.....She said. Deployed to occupied Japan as a member of the...', 'story_card_images/04d68518-aafb-497e-995e-10bc6e4bef90.jpg', '#2F4F4F', 6, 9, 2, 'ONGOING', 4.7, 1950, 42000),
('Heart of Their City (A Why Choose Mafia Romance)', 'heart-of-their-city', 1, 'I''m not afraid of death. Not when I know firsthand there are worse things that can happen to someone who''s still alive.', 'story_card_images/0d88ca6e-bdb9-4d45-b7f4-013f0ef843e5.jpg', '#DC143C', 1, 4, 1, 'ONGOING', 4.8, 2450, 58000),
('No Light without Darkness', 'no-light-without-darkness', 1, 'My dear English-speaking readers, I''m a French author and I''m not bilingual. In order to share my novel with you, I''ve used DeepL...', 'story_card_images/19eb26e8-6ee4-4010-8848-8f5779f602dd.jpg', '#FFB6C1', 2, 1, 3, 'ONGOING', 4.6, 1650, 38000),
('If It Means A Lot', 'if-it-means-a-lot', 1, 'Karsh is grieving. After his best friend died, he thought all was lost, that is until he wanders into a mystical bar where...', 'story_card_images/32b84f85-8e95-4a2d-8674-f3dc957133c8.jpg', '#FF8C00', 10, 8, 1, 'ONGOING', 4.4, 1500, 32000),
('Obedience in Ink', 'obedience-in-ink', 1, 'She only wanted to read the story. He made her live it.', 'story_card_images/4803aa58-6dc5-4816-b1d7-3d955156f1ca.jpg', '#FF69B4', 1, 4, 2, 'COMPLETED', 5.0, 3100, 72000),
('Casa Bianchi', 'casa-bianchi', 1, 'Teresa is a woman in her late thirties. From the outside, her life looks like many others. From the inside, it is quiet in ways that wear on a person...', 'story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg', '#2F4F4F', 6, 4, 2, 'ONGOING', 4.9, 2800, 64000),
('The Cedar House', 'the-cedar-house', 1, 'Cedar Falls was supposed to be temporary. So was he. Jess returns to her hometown for six weeks — sell the house, close the chapter, leave...', 'story_card_images/a16e9738-0207-421b-84ac-f9c7193f77df.jpg', '#E86C9F', 1, 9, 1, 'ONGOING', 4.5, 1900, 44000),
('Faith through famine', 'faith-through-famine', 1, 'Annie O''Roarke has lost everything. Her husband, her home and her family. It is 1847 in Ireland. The great potato famine has overtaken the land...', 'story_card_images/6a5c2a85-2d8c-498d-9153-1d72ec4005e4.jpg', '#8B4513', 9, 1, 2, 'COMPLETED', 5.0, 2600, 61000),
('Haven House', 'haven-house', 1, 'A gothic mystery about secrets, shadows, and second chances in an old New England manor.', 'story_card_images/b38a56a4-02f3-4d51-aa3e-469b25e77806.jpg', '#2F4F4F', 6, 2, 3, 'ONGOING', 4.7, 2200, 51000),
('The Wild Beyond the Walls', 'the-wild-beyond', 1, 'Five years after the world as she knew it ended, Shara has built a sanctuary in the heart of the jungle — a place untouched by the undead outside...', 'story_card_images/7d7d5cc8-5b0a-4821-9e57-3f58c36998b0.jpg', '#FF8C00', 8, 2, 1, 'ONGOING', 4.6, 1800, 41000);

-- Sample Chapters
INSERT INTO chapters (story_id, chapter_number, title, content, word_count, published_at) VALUES
(1, 1, 'Prologue: The Public Game', 'In the glittering world of professional racing, Babe and Charlie are known as rivals. Their public feuds are legendary, their competitive spirit legendary. But behind closed doors...', 1250, NOW()),
(1, 2, 'Chapter 1: Behind Closed Doors', 'The roar of the crowd faded as Charlie stepped into the empty garage. Only one person was waiting, and it wasn''t a competitor...', 1500, DATE_ADD(NOW(), INTERVAL 1 DAY)),
(2, 1, 'Chapter 1: Echoes', 'Some people come back into your life like an echo of what was. Other times, they arrive like a completely new story waiting to be written...', 1300, NOW()),
(3, 1, 'Chapter 1: Scent', 'The rejection still stings, even after six years. But what doesn''t kill you makes you powerful...', 1450, NOW()),
(4, 1, 'Chapter 1: Awakening', 'Kai''s eyes opened to an impossible world. The sky was purple. The gravity felt different. And the power flowing through his veins...', 1600, NOW());

-- Menu Structure
INSERT INTO menu_sections (name, display_order) VALUES
('Account', 1),
('Community', 2),
('Settings', 3),
('Support', 4);

INSERT INTO menu_items (label, icon, route, menu_section_id, display_order) VALUES
('Profile', 'person', 'profile', 1, 1),
('Statistics', 'bar_chart', 'stats', 1, 2),
('Groups', 'groups', 'groups', 2, 1),
('Help Center', 'help', 'help', 4, 1),
('Chat Support', 'chat', 'chat', 4, 2),
('Language', 'language', 'language', 3, 1),
('Favorites', 'favorite', 'favorites', 1, 3),
('Recommend a Story', 'auto_awesome', 'recommend', 2, 2),
('Cookies Policy', 'cookie', 'cookies', 4, 3),
('Terms of Service', 'description', 'terms', 4, 4),
('Privacy Policy', 'lock', 'privacy', 4, 5),
('Sign Out', 'logout', 'logout', 1, 4);

-- Achievement Groups and Badges
INSERT INTO achievement_groups (name, display_order) VALUES
('Reading Milestones', 1),
('Social Achievements', 2),
('Special Badges', 3);

INSERT INTO achievements (group_id, title, badge_value, style, progress_label, display_order) VALUES
(1, 'First Chapter', '📖', 'gold', '1/1 Chapters', 1),
(1, '10 Chapters', '10', 'gold', '10/10 Chapters', 2),
(1, '50 Chapters', '50', 'gold', '50/50 Chapters', 3),
(2, 'First Follower', '👥', 'silver', '1/1 Follower', 1),
(2, '100 Followers', '100', 'dark', '100/100 Followers', 2),
(3, 'Bookworm', '📚', 'black', 'Read 5 Stories', 3);

-- Sample User (for testing)
INSERT INTO users (username, email, display_name, bio, is_author) VALUES
('demo_user', 'demo@inkitt.local', 'Demo Reader', 'A passionate reader exploring amazing stories', FALSE);

INSERT INTO user_stats (user_id, followers, following, blocked, chapters_read, social_karma, day_streak) VALUES
(2, 156, 89, 0, 243, 450, 12);

-- Sample Reading Lists
INSERT INTO reading_lists (user_id, name, description, cover_path, story_count) VALUES
(2, 'Favorite Romances', 'My collection of heart-melting romance stories', 'story_card_images/a5f489f6-2a42-43c0-a190-2da06adfebf8.jpg', 8),
(2, 'Fantasy Adventures', 'Epic quests and magical worlds', 'story_card_images/5ba33f5b-f733-4dd3-a3d8-ad66dacfb093.jpg', 5);

-- Sample Library Entries
INSERT INTO library_entries (user_id, story_id, reading_status, last_read_chapter, progress_percent) VALUES
(2, 1, 'COMPLETED', 15, 100),
(2, 2, 'READING', 8, 45),
(2, 3, 'READING', 12, 62),
(2, 5, 'COMPLETED', 20, 100),
(2, 7, 'READING', 5, 28);

-- Sample Notifications
INSERT INTO notifications (user_id, message, notification_type, created_at) VALUES
(2, 'New chapter in "Scent of Another Alpha"!', 'STORY', NOW()),
(2, 'Your favorite author published a new story!', 'STORY', DATE_SUB(NOW(), INTERVAL 2 HOUR)),
(2, 'You have 5 new followers', 'COMMUNITY', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(2, 'Welcome to Inkitt! Start exploring amazing stories.', 'SYSTEM', DATE_SUB(NOW(), INTERVAL 3 DAY));
