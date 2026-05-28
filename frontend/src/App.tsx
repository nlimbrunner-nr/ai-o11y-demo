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

// Custom Amplify theme — clean dark
const amplifyTheme: Theme = {
  name: 'dark-car-theme',
  tokens: {
    colors: {
      background: {
        primary: '#111113',
        secondary: '#09090b',
      },
      font: {
        primary: '#fafafa',
        secondary: '#a1a1aa',
        interactive: '#fafafa',
      },
      brand: {
        primary: {
          10: 'rgba(255, 255, 255, 0.04)',
          20: 'rgba(255, 255, 255, 0.08)',
          40: 'rgba(255, 255, 255, 0.2)',
          60: 'rgba(255, 255, 255, 0.5)',
          80: 'rgba(255, 255, 255, 0.85)',
          90: '#fafafa',
          100: '#ffffff',
        },
      },
      border: {
        primary: 'rgba(255, 255, 255, 0.15)',
        secondary: 'rgba(255, 255, 255, 0.08)',
      },
    },
    components: {
      authenticator: {
        router: {
          borderWidth: '1px',
          borderColor: 'rgba(255, 255, 255, 0.09)',
          backgroundColor: 'rgba(17, 17, 19, 0.95)',
          boxShadow: '0 8px 32px rgba(0, 0, 0, 0.5)',
        },
      },
      button: {
        primary: {
          backgroundColor: '#fafafa',
          color: '#09090b',
          _hover: {
            backgroundColor: '#e4e4e7',
          },
          _focus: {
            backgroundColor: '#e4e4e7',
            boxShadow: '0 0 0 2px rgba(255, 255, 255, 0.3)',
          },
          _active: {
            backgroundColor: '#d4d4d8',
          },
        },
        link: {
          color: '#a1a1aa',
          _hover: {
            color: '#fafafa',
          },
        },
      },
      fieldcontrol: {
        borderRadius: '4px',
        borderColor: 'rgba(255, 255, 255, 0.14)',
        color: '#fafafa',
        _focus: {
          borderColor: 'rgba(255, 255, 255, 0.35)',
          boxShadow: '0 0 0 1px rgba(255, 255, 255, 0.15)',
        },
      },
      tabs: {
        item: {
          color: '#52525b',
          _hover: {
            color: '#a1a1aa',
          },
          _active: {
            borderColor: '#fafafa',
            color: '#fafafa',
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
        backgroundColor: '#09090b',
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
          backgroundColor: '#09090b',
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
                      color: '#fafafa',
                      letterSpacing: '-0.02em',
                      fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
                      mb: 0.5,
                      lineHeight: 1.1,
                    }}
                  >
                    AI O11y Automotive Demo
                  </Typography>
                  <Typography
                    sx={{
                      fontSize: '0.9rem',
                      color: '#71717a',
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
        <CircularProgress sx={{ color: '#a1a1aa' }} />
      </Box>
    );
  }

  return <AppContent userEmail={userEmail} signOut={signOut} />;
}

export default App;
