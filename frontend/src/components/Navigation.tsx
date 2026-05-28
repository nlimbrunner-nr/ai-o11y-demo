import React from 'react';
import { AppBar, Toolbar, Typography, Box, Button } from '@mui/material';
import { Logout as LogoutIcon } from '@mui/icons-material';
import { signOut } from 'aws-amplify/auth';
import toast from 'react-hot-toast';

interface NavigationProps {
  userEmail: string;
  signOut?: () => void;
}

export const Navigation: React.FC<NavigationProps> = ({ userEmail, signOut: amplifySignOut }) => {
  const handleSignOut = async () => {
    try {
      if (amplifySignOut) {
        amplifySignOut();
      } else {
        await signOut();
      }
    } catch (error) {
      console.error('Sign out error:', error);
      toast.error('Failed to sign out', {
        style: {
          background: '#1a1e30',
          color: '#fff',
        },
      });
    }
  };

  return (
    <AppBar
      position="fixed"
      elevation={0}
      sx={{
        backgroundColor: 'rgba(10, 15, 30, 0.85)',
        backdropFilter: 'blur(12px)',
        borderBottom: '1px solid rgba(255, 255, 255, 0.1)',
        zIndex: (theme) => theme.zIndex.drawer + 1,
      }}
    >
      <Toolbar sx={{ justifyContent: 'space-between', px: { xs: 2, sm: 3 } }}>
        {/* App Name */}
        <Typography
          variant="h6"
          sx={{
            fontWeight: 700,
            color: '#ffffff',
            fontSize: '1.1rem',
            letterSpacing: '-0.01em',
          }}
        >
          AI Car Demo
        </Typography>

        {/* User Info + Sign Out */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <Typography
            sx={{
              color: 'rgba(255, 255, 255, 0.7)',
              fontSize: '0.875rem',
              display: { xs: 'none', sm: 'block' },
            }}
          >
            {userEmail}
          </Typography>
          <Button
            onClick={handleSignOut}
            startIcon={<LogoutIcon />}
            size="small"
            sx={{
              color: 'rgba(255, 255, 255, 0.7)',
              textTransform: 'none',
              fontSize: '0.875rem',
              '&:hover': {
                color: '#ffffff',
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
              },
            }}
          >
            Sign Out
          </Button>
        </Box>
      </Toolbar>
    </AppBar>
  );
};
