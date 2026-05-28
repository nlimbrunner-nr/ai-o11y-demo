import React, { useState, useRef, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  TextField,
  InputAdornment,
  IconButton,
  CircularProgress,
  Tooltip,
} from '@mui/material';
import { Send as SendIcon, RestartAlt as ResetIcon } from '@mui/icons-material';
import { fetchAuthSession, fetchUserAttributes } from 'aws-amplify/auth';
import toast from 'react-hot-toast';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

interface ChatPanelProps {
  vehicleId?: string;
  height?: string;
}

export const ChatPanel: React.FC<ChatPanelProps> = ({ vehicleId, height = '100%' }) => {
  const [chatInput, setChatInput] = useState('');
  const [chatMessages, setChatMessages] = useState<ChatMessage[]>([]);
  const [isSendingMessage, setIsSendingMessage] = useState(false);
  const [sessionId, setSessionId] = useState(() => crypto.randomUUID());
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom when new messages arrive
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
      // Get auth token and user email from Cognito
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
        style: {
          background: '#1a1e30',
          color: '#fff',
        },
      });
    } finally {
      setIsSendingMessage(false);
    }
  };

  const handleResetChat = () => {
    setChatMessages([]);
    setSessionId(crypto.randomUUID());
    toast.success('Chat reset', {
      style: {
        background: '#1a1e30',
        color: '#fff',
      },
    });
  };

  const handleKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendChatMessage();
    }
  };

  return (
    <Card
      elevation={0}
      sx={{
        width: '100%',
        height: height,
        backgroundColor: 'rgba(15, 25, 45, 0.65)',
        backgroundImage: 'linear-gradient(135deg, rgba(20, 30, 60, 0.6), rgba(30, 20, 50, 0.6))',
        backdropFilter: 'blur(15px)',
        borderRadius: 3,
        border: '1px solid rgba(255, 255, 255, 0.15)',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
      }}
    >
      <CardContent
        sx={{
          p: 3,
          display: 'flex',
          flexDirection: 'column',
          height: '100%',
          overflow: 'hidden',
          '&:last-child': { pb: 3 },
        }}
      >
        {/* Chat Header */}
        <Box sx={{ mb: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Typography
            sx={{
              color: '#ffffff',
              fontSize: '1.1rem',
              fontWeight: 600,
            }}
          >
            Chat with your Car
          </Typography>
          {chatMessages.length > 0 && (
            <Tooltip title="Reset chat">
              <IconButton
                onClick={handleResetChat}
                disabled={isSendingMessage}
                sx={{
                  color: 'rgba(255, 255, 255, 0.7)',
                  '&:hover': {
                    backgroundColor: 'rgba(255, 255, 255, 0.1)',
                    color: '#ffffff',
                  },
                  '&.Mui-disabled': {
                    color: 'rgba(255, 255, 255, 0.3)',
                  },
                }}
                size="small"
              >
                <ResetIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
        </Box>

        {/* Chat Messages Area */}
        <Box
          sx={{
            flex: 1,
            minHeight: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.2)',
            borderRadius: 1,
            p: 2,
            mb: 2,
            overflowY: 'auto',
            overflowX: 'hidden',
            display: 'flex',
            flexDirection: 'column',
            gap: 2,
            '&::-webkit-scrollbar': {
              width: '8px',
            },
            '&::-webkit-scrollbar-track': {
              background: 'rgba(255, 255, 255, 0.1)',
              borderRadius: '4px',
            },
            '&::-webkit-scrollbar-thumb': {
              background: 'rgba(255, 255, 255, 0.3)',
              borderRadius: '4px',
              '&:hover': {
                background: 'rgba(255, 255, 255, 0.5)',
              },
            },
          }}
        >
          {chatMessages.length === 0 ? (
            <Typography
              sx={{
                color: 'rgba(255, 255, 255, 0.6)',
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
                  maxWidth: '80%',
                }}
              >
                <Box
                  sx={{
                    p: 1.5,
                    borderRadius: 2,
                    backgroundColor:
                      message.role === 'user'
                        ? 'rgba(255, 255, 255, 0.2)'
                        : 'rgba(255, 255, 255, 0.1)',
                    border:
                      message.role === 'user'
                        ? '1px solid rgba(255, 255, 255, 0.3)'
                        : '1px solid rgba(255, 255, 255, 0.15)',
                  }}
                >
                  <Typography
                    sx={{
                      color: '#ffffff',
                      fontSize: '0.875rem',
                      whiteSpace: 'pre-wrap',
                      wordBreak: 'break-word',
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
              <CircularProgress size={20} sx={{ color: 'rgba(255, 255, 255, 0.6)' }} />
            </Box>
          )}
          {/* Invisible scroll anchor */}
          <div ref={messagesEndRef} />
        </Box>

        {/* Chat Input */}
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
            '& .MuiOutlinedInput-root': {
              color: '#ffffff',
              backgroundColor: 'rgba(255, 255, 255, 0.1)',
              '& fieldset': {
                borderColor: 'rgba(255, 255, 255, 0.3)',
              },
              '&:hover fieldset': {
                borderColor: 'rgba(255, 255, 255, 0.5)',
              },
              '&.Mui-focused fieldset': {
                borderColor: 'rgba(255, 255, 255, 0.7)',
              },
            },
            '& .MuiInputBase-input::placeholder': {
              color: 'rgba(255, 255, 255, 0.5)',
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
                    color: '#ffffff',
                    '&:hover': {
                      backgroundColor: 'rgba(255, 255, 255, 0.1)',
                    },
                    '&.Mui-disabled': {
                      color: 'rgba(255, 255, 255, 0.3)',
                    },
                  }}
                >
                  <SendIcon />
                </IconButton>
              </InputAdornment>
            ),
          }}
        />
      </CardContent>
    </Card>
  );
};
