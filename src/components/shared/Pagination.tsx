import { Icon } from './Icon';
import './Pagination.css';

interface PaginationProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) =>void;
  pageNumbers: (number | string)[];
}

export const Pagination = ({
  currentPage,
  totalPages,
  onPageChange,
  pageNumbers,
}: PaginationProps) => {
  if (totalPages <= 1) return null;

  return (
    <div className="pagination">
      <button
        onClick={() => onPageChange(currentPage - 1)}
        disabled={currentPage === 1}
        className="pagination-button pagination-prev"
        aria-label="Previous page"
      >
        <Icon name="chevronLeft" size={20} />
        Previous
      </button>

      <div className="pagination-pages">
        {pageNumbers.map((page, index) =>
          typeof page === 'number' ? (
            <button
              key={index}
              onClick={() => onPageChange(page)}
              className={`pagination-page ${currentPage === page ? 'active' : ''}`}
            >
              {page}
            </button>
          ) : (
            <span key={index} className="pagination-ellipsis">
              {page}
            </span>
          )
        )}
      </div>

      <button
        onClick={() => onPageChange(currentPage + 1)}
        disabled={currentPage === totalPages}
        className="pagination-button pagination-next"
        aria-label="Next page"
      >
        Next
        <Icon name="chevronRight" size={20} />
      </button>
    </div>
  );
};
