import React, { useState, useRef, useEffect } from 'react';
import {
  Box,
  Typography,
  TextField,
  InputAdornment,
  IconButton,
  CircularProgress,
  Tooltip,
} from '@mui/material';
import { Send as SendIcon, RestartAlt as ResetIcon, Close as CloseIcon } from '@mui/icons-material';
import { fetchAuthSession, fetchUserAttributes } from 'aws-amplify/auth';
import toast from 'react-hot-toast';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

interface ChatPanelProps {
  vehicleId?: string;
  height?: string;
  onClose?: () => void;
}

export const ChatPanel: React.FC<ChatPanelProps> = ({ vehicleId, height = '100%', onClose }) => {
  const [chatInput, setChatInput] = useState('');
  const [chatMessages, setChatMessages] = useState<ChatMessage[]>([]);
  const [isSendingMessage, setIsSendingMessage] = useState(false);
  const [sessionId, setSessionId] = useState(() => crypto.randomUUID());
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages, isSendingMessage]);

  const sendChatMessage = async () => {
    if (!chatInput.trim() || isSendingMessage) return;

    const userMessage = chatInput.trim();
    setChatInput('');
    setIsSendingMessage(true);

    const newUserMessage: ChatMessage = { role: 'user', content: userMessage };
    const updatedMessages = [...chatMessages, newUserMessage];
    setChatMessages(updatedMessages);

    try {
      const session = await fetchAuthSession();
      const token = session.tokens?.idToken?.toString();

      if (!token) {
        throw new Error('Not authenticated');
      }

      const userAttributes = await fetchUserAttributes();
      const userEmail = userAttributes.email;

      const response = await fetch(`${process.env.REACT_APP_API_URL}/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          message: userMessage,
          auth_token: token,
          session_id: sessionId,
          user_email: userEmail,
        }),
      });

      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }

      const data = await response.json();

      const assistantMessage: ChatMessage = {
        role: 'assistant',
        content: data.response,
      };
      setChatMessages((prev) => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Chat error:', error);
      toast.error('Failed to send message', {
        style: { background: '#18181b', color: '#fafafa' },
      });
    } finally {
      setIsSendingMessage(false);
    }
  };

  const handleResetChat = () => {
    setChatMessages([]);
    setSessionId(crypto.randomUUID());
    toast.success('Chat reset', {
      style: { background: '#18181b', color: '#fafafa' },
    });
  };

  const handleKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendChatMessage();
    }
  };

  return (
    <Box
      sx={{
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* Header */}
      <Box
        sx={{
          flexShrink: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          mb: 2,
          pb: 2,
          borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
        }}
      >
        <Typography
          sx={{
            color: '#fafafa',
            fontSize: '1rem',
            fontWeight: 600,
            letterSpacing: '-0.01em',
          }}
        >
          Chat with your Car
        </Typography>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
          {chatMessages.length > 0 && (
            <Tooltip title="Reset chat">
              <IconButton
                onClick={handleResetChat}
                disabled={isSendingMessage}
                size="small"
                sx={{
                  color: '#71717a',
                  '&:hover': { backgroundColor: 'rgba(255, 255, 255, 0.06)', color: '#fafafa' },
                  '&.Mui-disabled': { color: 'rgba(113, 113, 122, 0.3)' },
                }}
              >
                <ResetIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
          {onClose && (
            <Tooltip title="Close">
              <IconButton
                onClick={onClose}
                size="small"
                sx={{
                  color: '#71717a',
                  '&:hover': { backgroundColor: 'rgba(255, 255, 255, 0.06)', color: '#fafafa' },
                }}
              >
                <CloseIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
        </Box>
      </Box>

      {/* Messages area */}
      <Box
        sx={{
          flex: 1,
          minHeight: 0,
          p: 0,
          mb: 2,
          overflowY: 'auto',
          overflowX: 'hidden',
          display: 'flex',
          flexDirection: 'column',
          gap: 1.5,
          '&::-webkit-scrollbar': { width: '4px' },
          '&::-webkit-scrollbar-track': { background: 'transparent' },
          '&::-webkit-scrollbar-thumb': {
            background: 'rgba(255, 255, 255, 0.15)',
            borderRadius: '2px',
          },
        }}
      >
        {chatMessages.length === 0 ? (
          <Typography
            sx={{
              color: '#52525b',
              fontSize: '0.875rem',
              fontStyle: 'italic',
            }}
          >
            Ask me anything about your vehicle...
          </Typography>
        ) : (
          chatMessages.map((message, index) => (
            <Box
              key={index}
              sx={{
                alignSelf: message.role === 'user' ? 'flex-end' : 'flex-start',
                maxWidth: '85%',
              }}
            >
              <Box
                sx={{
                  p: 1.5,
                  borderRadius: 2,
                  backgroundColor:
                    message.role === 'user' ? '#0ea5e9' : 'rgba(255, 255, 255, 0.06)',
                  border: message.role === 'user' ? 'none' : '1px solid rgba(255, 255, 255, 0.08)',
                }}
              >
                <Typography
                  sx={{
                    color: message.role === 'user' ? '#fff' : '#e4e4e7',
                    fontSize: '0.875rem',
                    whiteSpace: 'pre-wrap',
                    wordBreak: 'break-word',
                    lineHeight: 1.55,
                  }}
                >
                  {message.content}
                </Typography>
              </Box>
            </Box>
          ))
        )}
        {isSendingMessage && (
          <Box sx={{ alignSelf: 'flex-start' }}>
            <CircularProgress size={18} sx={{ color: '#71717a' }} />
          </Box>
        )}
        <div ref={messagesEndRef} />
      </Box>

      {/* Input */}
      <TextField
        fullWidth
        placeholder="Type a message..."
        variant="outlined"
        size="small"
        value={chatInput}
        onChange={(e) => setChatInput(e.target.value)}
        onKeyDown={handleKeyDown}
        disabled={isSendingMessage}
        sx={{
          flexShrink: 0,
          '& .MuiOutlinedInput-root': {
            color: '#fafafa',
            backgroundColor: 'rgba(0, 0, 0, 0.2)',
            borderRadius: 2,
            '& fieldset': { borderColor: 'rgba(255, 255, 255, 0.12)' },
            '&:hover fieldset': { borderColor: 'rgba(255, 255, 255, 0.25)' },
            '&.Mui-focused fieldset': { borderColor: 'rgba(14, 165, 233, 0.6)' },
          },
          '& .MuiInputBase-input::placeholder': {
            color: '#52525b',
            opacity: 1,
          },
        }}
        InputProps={{
          endAdornment: (
            <InputAdornment position="end">
              <IconButton
                edge="end"
                onClick={sendChatMessage}
                disabled={!chatInput.trim() || isSendingMessage}
                sx={{
                  color: '#0ea5e9',
                  '&:hover': { backgroundColor: 'rgba(14, 165, 233, 0.1)' },
                  '&.Mui-disabled': { color: 'rgba(255, 255, 255, 0.2)' },
                }}
              >
                <SendIcon fontSize="small" />
              </IconButton>
            </InputAdornment>
          ),
        }}
      />
    </Box>
  );
};
