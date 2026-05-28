import React, { useState } from 'react';
import { useQuery, gql } from '@apollo/client';
import {
  Container,
  Box,
  Typography,
  Card,
  CardContent,
  LinearProgress,
  CircularProgress,
  Button,
} from '@mui/material';
import {
  Lock as LockIcon,
  LockOpen as LockOpenIcon,
  BatteryChargingFull as BatteryIcon,
  Speed as SpeedIcon,
  Build as BuildIcon,
  TireRepair as TireIcon,
  Refresh as RefreshIcon,
} from '@mui/icons-material';
import toast from 'react-hot-toast';
import { ChatPanel } from '../components/ChatPanel';

const GET_USER = gql`
  query GetUser($email: String!) {
    user(email: $email) {
      email
      name
      vehicle {
        id
        model
        batteryLevel
        rangeKm
        totalKm
        nextServiceKm
        tirePressure
        softwareVersion
        isLocked
        lastUpdated
      }
    }
  }
`;

interface Vehicle {
  id: string;
  model: string;
  batteryLevel: number;
  rangeKm: number;
  totalKm: number;
  nextServiceKm: number;
  tirePressure: number;
  softwareVersion: string;
  isLocked: boolean;
  lastUpdated: string;
}

interface User {
  email: string;
  name: string;
  vehicle: Vehicle | null;
}

interface GetUserData {
  user: User | null;
}

interface OverviewProps {
  userEmail: string;
}

export const Overview: React.FC<OverviewProps> = ({ userEmail }) => {
  const { loading, error, data, refetch } = useQuery<GetUserData>(GET_USER, {
    variables: { email: userEmail },
    pollInterval: 30000,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'cache-and-network',
  });

  const [carImageError, setCarImageError] = useState(false);

  const handleRefresh = async () => {
    toast.loading('Fetching latest vehicle data...', {
      id: 'vehicle-refresh',
      style: { background: '#1a1e30', color: '#fff' },
    });

    try {
      await refetch();
      toast.success('Vehicle data updated', {
        id: 'vehicle-refresh',
        style: { background: '#1a1e30', color: '#fff' },
      });
    } catch (err) {
      toast.error('Failed to update vehicle data', {
        id: 'vehicle-refresh',
        style: { background: '#1a1e30', color: '#fff' },
      });
    }
  };

  if (loading) {
    return (
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          minHeight: 'calc(100vh - 72px)',
        }}
      >
        <CircularProgress sx={{ color: '#ffffff' }} />
      </Box>
    );
  }

  if (error) {
    return (
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'center',
          minHeight: 'calc(100vh - 72px)',
          gap: 2,
        }}
      >
        <Typography sx={{ color: '#ffffff' }}>
          Error loading vehicle data: {error.message}
        </Typography>
        <Button
          onClick={handleRefresh}
          startIcon={<RefreshIcon />}
          variant="outlined"
          sx={{ color: '#ffffff', borderColor: 'rgba(255,255,255,0.4)' }}
        >
          Retry
        </Button>
      </Box>
    );
  }

  const user = data?.user;
  const vehicle = user?.vehicle;

  const cardSx = {
    elevation: 0,
    backgroundColor: 'rgba(15, 25, 45, 0.65)',
    backgroundImage: 'linear-gradient(135deg, rgba(20, 30, 60, 0.6), rgba(30, 20, 50, 0.6))',
    backdropFilter: 'blur(15px)',
    borderRadius: 3,
    border: '1px solid rgba(255, 255, 255, 0.15)',
    overflow: 'hidden',
  };

  const statBoxSx = {
    p: 2,
    backgroundColor: 'rgba(0, 0, 0, 0.2)',
    borderRadius: 1,
    border: '1px solid rgba(255, 255, 255, 0.1)',
  };

  return (
    <Container maxWidth="xl" sx={{ pt: 2, pb: 4 }}>
      <Box
        sx={{
          display: 'flex',
          gap: 3,
          alignItems: 'stretch',
          minHeight: 'calc(100vh - 120px)',
        }}
      >
        {/* ── Left Column: Vehicle Status ── */}
        <Card
          elevation={0}
          sx={{
            flex: 1,
            ...cardSx,
          }}
        >
          <CardContent sx={{ p: 3 }}>
            {/* Vehicle model name */}
            <Box sx={{ textAlign: 'center', mb: 3 }}>
              <Typography
                sx={{
                  color: 'rgba(255, 255, 255, 0.7)',
                  fontSize: '0.9rem',
                  fontWeight: 500,
                  letterSpacing: '0.1em',
                  textTransform: 'uppercase',
                }}
              >
                {vehicle?.model ?? 'No Vehicle'}
              </Typography>
            </Box>

            {/* Car image or placeholder */}
            <Box sx={{ textAlign: 'center', mb: 3 }}>
              {!carImageError ? (
                <img
                  src="/images/car.png"
                  alt="Vehicle"
                  onError={() => setCarImageError(true)}
                  style={{
                    width: '100%',
                    maxWidth: '500px',
                    height: 'auto',
                  }}
                />
              ) : (
                <Box
                  sx={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    width: '100%',
                    maxWidth: 500,
                    height: 200,
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                    borderRadius: 2,
                    border: '2px dashed rgba(255, 255, 255, 0.2)',
                  }}
                >
                  <Typography sx={{ color: 'rgba(255, 255, 255, 0.4)', fontSize: '0.9rem' }}>
                    Car Image
                  </Typography>
                </Box>
              )}
            </Box>

            {/* Lock status */}
            <Box sx={{ textAlign: 'center', mb: 3 }}>
              <Box
                sx={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  width: 48,
                  height: 48,
                  borderRadius: '50%',
                  border: '2px solid rgba(255, 255, 255, 0.3)',
                  mb: 1,
                }}
              >
                {vehicle?.isLocked ? (
                  <LockIcon sx={{ color: '#ffffff', fontSize: 24 }} />
                ) : (
                  <LockOpenIcon sx={{ color: '#ffffff', fontSize: 24 }} />
                )}
              </Box>
              <Typography
                sx={{
                  color: 'rgba(255, 255, 255, 0.7)',
                  fontSize: '0.8rem',
                }}
              >
                {vehicle?.isLocked ? 'Locked' : 'Unlocked'}
              </Typography>
              {vehicle?.lastUpdated && (
                <Typography
                  variant="caption"
                  sx={{
                    color: 'rgba(255, 255, 255, 0.5)',
                    fontSize: '0.75rem',
                    display: 'block',
                    mt: 0.5,
                  }}
                >
                  Updated: {new Date(vehicle.lastUpdated).toLocaleString()}
                </Typography>
              )}
            </Box>

            {/* Battery level */}
            <Box sx={{ mt: 2 }}>
              <Box
                sx={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  mb: 1,
                }}
              >
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <BatteryIcon sx={{ color: '#ffffff', fontSize: 20 }} />
                  <Typography sx={{ color: '#ffffff', fontSize: '0.9rem' }}>Battery</Typography>
                </Box>
                <Typography sx={{ color: '#ffffff', fontSize: '1.1rem', fontWeight: 600 }}>
                  {vehicle?.batteryLevel ?? 0}
                  <span style={{ fontSize: '0.85rem' }}> %</span>
                </Typography>
              </Box>
              <LinearProgress
                variant="determinate"
                value={vehicle?.batteryLevel ?? 0}
                sx={{
                  height: 6,
                  borderRadius: 1,
                  backgroundColor: 'rgba(255, 255, 255, 0.2)',
                  '& .MuiLinearProgress-bar': {
                    backgroundColor: '#ffffff',
                    borderRadius: 1,
                  },
                }}
              />
            </Box>

            {/* Stats grid: 2×2 */}
            <Box
              sx={{
                mt: 3,
                display: 'grid',
                gridTemplateColumns: 'repeat(2, 1fr)',
                gap: 2,
              }}
            >
              {/* Range */}
              <Box sx={statBoxSx}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 0.5 }}>
                  <SpeedIcon sx={{ color: 'rgba(255,255,255,0.5)', fontSize: 14 }} />
                  <Typography sx={{ color: 'rgba(255, 255, 255, 0.7)', fontSize: '0.75rem' }}>
                    Range
                  </Typography>
                </Box>
                <Typography sx={{ color: '#ffffff', fontSize: '1.2rem', fontWeight: 600 }}>
                  {vehicle?.rangeKm?.toLocaleString() ?? 0} km
                </Typography>
              </Box>

              {/* Total km */}
              <Box sx={statBoxSx}>
                <Typography
                  sx={{ color: 'rgba(255, 255, 255, 0.7)', fontSize: '0.75rem', mb: 0.5 }}
                >
                  Total km
                </Typography>
                <Typography sx={{ color: '#ffffff', fontSize: '1.2rem', fontWeight: 600 }}>
                  {vehicle?.totalKm?.toLocaleString() ?? 0} km
                </Typography>
              </Box>

              {/* Next service */}
              <Box sx={statBoxSx}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 0.5 }}>
                  <BuildIcon sx={{ color: 'rgba(255,255,255,0.5)', fontSize: 14 }} />
                  <Typography sx={{ color: 'rgba(255, 255, 255, 0.7)', fontSize: '0.75rem' }}>
                    Next Service
                  </Typography>
                </Box>
                <Typography sx={{ color: '#ffffff', fontSize: '1.2rem', fontWeight: 600 }}>
                  {vehicle?.nextServiceKm?.toLocaleString() ?? 0} km
                </Typography>
              </Box>

              {/* Tire pressure */}
              <Box sx={statBoxSx}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 0.5 }}>
                  <TireIcon sx={{ color: 'rgba(255,255,255,0.5)', fontSize: 14 }} />
                  <Typography sx={{ color: 'rgba(255, 255, 255, 0.7)', fontSize: '0.75rem' }}>
                    Tire Pressure
                  </Typography>
                </Box>
                <Typography sx={{ color: '#ffffff', fontSize: '1.2rem', fontWeight: 600 }}>
                  {vehicle?.tirePressure ?? 0} PSI
                </Typography>
              </Box>
            </Box>

            {/* Refresh button */}
            <Box sx={{ mt: 3, textAlign: 'center' }}>
              <Button
                onClick={handleRefresh}
                startIcon={<RefreshIcon />}
                variant="outlined"
                size="small"
                sx={{
                  color: 'rgba(255, 255, 255, 0.8)',
                  borderColor: 'rgba(255, 255, 255, 0.3)',
                  textTransform: 'none',
                  '&:hover': {
                    borderColor: 'rgba(255, 255, 255, 0.6)',
                    backgroundColor: 'rgba(255, 255, 255, 0.05)',
                  },
                }}
              >
                Refresh
              </Button>
            </Box>
          </CardContent>
        </Card>

        {/* ── Right Column: Chat Panel ── */}
        <Box
          sx={{
            flex: 0.5,
            minWidth: 0,
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <ChatPanel vehicleId={vehicle?.id} height="100%" />
        </Box>
      </Box>
    </Container>
  );
};
