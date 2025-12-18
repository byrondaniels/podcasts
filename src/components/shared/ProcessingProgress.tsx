import type { ProcessingStep } from '../../types/episode';
import { Icon } from './Icon';
import './ProcessingProgress.css';

interface ProcessingProgressProps {
  step?: ProcessingStep;
}

const STEPS: { step: ProcessingStep; label: string }[] = [
  { step: 'downloading', label: 'Downloading' },
  { step: 'chunking', label: 'Chunking' },
  { step: 'transcribing', label: 'Transcribing' },
  { step: 'merging', label: 'Merging' },
  { step: 'completed', label: 'Completed' },
];

export const ProcessingProgress = ({ step }: ProcessingProgressProps) => {
  if (!step) {
    return null;
  }

  const currentStepIndex = STEPS.findIndex((s) => s.step === step);

  return (
    <div className="processing-progress">
      <div className="processing-progress-steps">
        {STEPS.map((s, index) => {
          const isCompleted = index < currentStepIndex;
          const isCurrent = index === currentStepIndex;
          const isPending = index > currentStepIndex;

          return (
            <div
              key={s.step}
              className={`processing-progress-step ${
                isCompleted ? 'completed' : isCurrent ? 'current' : 'pending'
              }`}
            >
              <div className="processing-progress-step-icon">
                {isCompleted ? (
                  <Icon name="check" size={16} />
                ) : isCurrent ? (
                  <div className="processing-progress-spinner" />
                ) : (
                  <div className="processing-progress-dot" />
                )}
              </div>
              <div className="processing-progress-step-label">{s.label}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
