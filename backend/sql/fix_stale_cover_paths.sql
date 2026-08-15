-- Fix stale cover paths in the live database
-- Maps old story*.jpg paths to valid UUID-based paths that exist in /uploads/

-- Update books table - replace stale story*.jpg paths with valid UUID paths
UPDATE books
SET cover_path = 'story_card_images/006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg'
WHERE cover_path IN ('story_card_images/story3.jpg', 'story3.jpg', 'story_card_images/story4.jpg', 'story4.jpg', 'story_card_images/story15.jpg', 'story15.jpg');

-- Also fix any other stale story*.jpg patterns
UPDATE books
SET cover_path = 'story_card_images/006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg'
WHERE cover_path LIKE 'story_card_images/story%.jpg'
   OR cover_path LIKE 'story%.jpg'
   OR cover_path LIKE 'uploads/story%.jpg';

-- Fix reading_lists table
UPDATE reading_lists
SET cover_path = 'story_card_images/8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg'
WHERE cover_path LIKE 'story_card_images/story%.jpg'
   OR cover_path LIKE 'story%.jpg'
   OR cover_path LIKE 'uploads/story%.jpg';

-- Fix library_entries via books join (library_entries references books by book_id)
-- No direct cover_path in library_entries, so no action needed there

-- Verify the fix
SELECT id, title, cover_path FROM books WHERE cover_path LIKE '%story%';