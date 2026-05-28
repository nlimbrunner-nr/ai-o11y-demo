import React, { useEffect, useState } from 'react';
import { Amplify } from 'aws-amplify';
import { fetchUserAttributes } from 'aws-amplify/auth';
import { Authenticator, ThemeProvider as AmplifyThemeProvider, Theme } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import { Box, CircularProgress, Typography } from '@mui/material';
import { Toaster } from 'react-hot-toast';
import { amplifyConfig } from './amplifyconfiguration';
import { Navigation } from './components/Navigation';
import { Overview } from './pages/Overview';

Amplify.configure(amplifyConfig);

// Custom Amplify theme matching dark aesthetic
const amplifyTheme: Theme = {
  name: 'dark-car-theme',
  tokens: {
    colors: {
      background: {
        primary: '#0d1424',
        secondary: '#0a0f1e',
      },
      font: {
        primary: '#ffffff',
        secondary: 'rgba(255, 255, 255, 0.7)',
        interactive: '#ffffff',
      },
      brand: {
        primary: {
          10: 'rgba(255, 255, 255, 0.05)',
          20: 'rgba(255, 255, 255, 0.1)',
          40: 'rgba(255, 255, 255, 0.3)',
          60: 'rgba(255, 255, 255, 0.6)',
          80: 'rgba(255, 255, 255, 0.8)',
          90: '#ffffff',
          100: '#ffffff',
        },
      },
      border: {
        primary: 'rgba(255, 255, 255, 0.2)',
        secondary: 'rgba(255, 255, 255, 0.1)',
      },
    },
    components: {
      authenticator: {
        router: {
          borderWidth: '1px',
          borderColor: 'rgba(255, 255, 255, 0.15)',
          backgroundColor: 'rgba(15, 25, 45, 0.9)',
          boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4)',
        },
      },
      button: {
        primary: {
          backgroundColor: 'rgba(255, 255, 255, 0.15)',
          color: '#ffffff',
          _hover: {
            backgroundColor: 'rgba(255, 255, 255, 0.25)',
          },
          _focus: {
            backgroundColor: 'rgba(255, 255, 255, 0.25)',
            boxShadow: '0 0 0 2px rgba(255, 255, 255, 0.3)',
          },
          _active: {
            backgroundColor: 'rgba(255, 255, 255, 0.3)',
          },
        },
        link: {
          color: 'rgba(255, 255, 255, 0.7)',
          _hover: {
            color: '#ffffff',
          },
        },
      },
      fieldcontrol: {
        borderRadius: '4px',
        borderColor: 'rgba(255, 255, 255, 0.2)',
        color: '#ffffff',
        _focus: {
          borderColor: 'rgba(255, 255, 255, 0.5)',
          boxShadow: '0 0 0 1px rgba(255, 255, 255, 0.3)',
        },
      },
      tabs: {
        item: {
          color: 'rgba(255, 255, 255, 0.5)',
          _hover: {
            color: 'rgba(255, 255, 255, 0.8)',
          },
          _active: {
            borderColor: '#ffffff',
            color: '#ffffff',
          },
        },
      },
    },
    fonts: {
      default: {
        variable: { value: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif' },
        static: { value: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif' },
      },
    },
    radii: {
      small: '4px',
      medium: '8px',
      large: '12px',
    },
  },
};

interface AppContentProps {
  userEmail: string;
  signOut?: () => void;
}

function AppContent({ userEmail, signOut }: AppContentProps) {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        backgroundColor: '#0a0f1e',
        pt: '72px',
      }}
    >
      <Navigation userEmail={userEmail} signOut={signOut} />
      <Overview userEmail={userEmail} />
    </Box>
  );
}

function App() {
  return (
    <AmplifyThemeProvider theme={amplifyTheme}>
      <Toaster position="top-center" />
      <Box
        sx={{
          minHeight: '100vh',
          backgroundColor: '#0a0f1e',
        }}
      >
        <Authenticator
          loginMechanisms={['email']}
          signUpAttributes={['email']}
          hideSignUp={true}
          components={{
            Header() {
              return (
                <Box
                  sx={{
                    textAlign: 'center',
                    pt: 6,
                    pb: 3,
                  }}
                >
                  <Typography
                    sx={{
                      fontSize: { xs: '2rem', sm: '2.5rem' },
                      fontWeight: 700,
                      color: '#ffffff',
                      letterSpacing: '-0.02em',
                      fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
                      mb: 0.5,
                      lineHeight: 1.1,
                    }}
                  >
                    AI Car Demo
                  </Typography>
                  <Typography
                    sx={{
                      fontSize: '0.9rem',
                      color: 'rgba(255, 255, 255, 0.6)',
                      fontWeight: 400,
                    }}
                  >
                    Vehicle Observability Dashboard
                  </Typography>
                </Box>
              );
            },
          }}
        >
          {({ signOut, user }) => {
            const loginId = user?.signInDetails?.loginId ?? '';
            return <AppContentWrapper loginId={loginId} signOut={signOut} />;
          }}
        </Authenticator>
      </Box>
    </AmplifyThemeProvider>
  );
}

interface AppContentWrapperProps {
  loginId: string;
  signOut?: () => void;
}

function AppContentWrapper({ loginId, signOut }: AppContentWrapperProps) {
  const [userEmail, setUserEmail] = useState<string>(loginId);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const getEmail = async () => {
      try {
        const attributes = await fetchUserAttributes();
        if (attributes.email) {
          setUserEmail(attributes.email);
        } else {
          setUserEmail(loginId);
        }
      } catch (err) {
        console.error('Failed to fetch user attributes:', err);
        setUserEmail(loginId);
      } finally {
        setLoading(false);
      }
    };
    getEmail();
  }, [loginId]);

  if (loading) {
    return (
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          minHeight: '100vh',
        }}
      >
        <CircularProgress sx={{ color: '#ffffff' }} />
      </Box>
    );
  }

  return <AppContent userEmail={userEmail} signOut={signOut} />;
}

export default App;
