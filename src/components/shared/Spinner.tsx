import './Spinner.css';

type SpinnerSize = 'small' | 'medium' | 'large';

interface SpinnerProps {
  size?: SpinnerSize;
  className?: string;
}

export const Spinner = ({ size = 'medium', className = '' }: SpinnerProps) => {
  return <span className={`spinner ${size} ${className}`}></span>;
};
