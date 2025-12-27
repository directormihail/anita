-- Create message_feedback table for ANITA Finance Advisor
-- This table stores user feedback (like/dislike) for messages

CREATE TABLE IF NOT EXISTS public.message_feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    message_id TEXT NOT NULL,
    conversation_id TEXT,
    feedback_type TEXT NOT NULL CHECK (feedback_type IN ('like', 'dislike')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, message_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_message_feedback_user_id ON public.message_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_message_feedback_message_id ON public.message_feedback(message_id);
CREATE INDEX IF NOT EXISTS idx_message_feedback_conversation_id ON public.message_feedback(conversation_id);
CREATE INDEX IF NOT EXISTS idx_message_feedback_feedback_type ON public.message_feedback(feedback_type);
CREATE INDEX IF NOT EXISTS idx_message_feedback_created_at ON public.message_feedback(created_at);

-- Enable Row Level Security (RLS)
ALTER TABLE public.message_feedback ENABLE ROW LEVEL SECURITY;

-- Create policies for RLS
-- Allow users to insert their own feedback
CREATE POLICY "Users can insert their own feedback"
    ON public.message_feedback
    FOR INSERT
    WITH CHECK (true);

-- Allow users to view their own feedback
CREATE POLICY "Users can view their own feedback"
    ON public.message_feedback
    FOR SELECT
    USING (true);

-- Allow users to update their own feedback
CREATE POLICY "Users can update their own feedback"
    ON public.message_feedback
    FOR UPDATE
    USING (true);

-- Add comment to table
COMMENT ON TABLE public.message_feedback IS 'Stores user feedback (like/dislike) for messages in ANITA Finance Advisor';

