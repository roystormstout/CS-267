! program to solve the heat equation (Dirichlet boundary conditions only)
PROGRAM main

implicit none

! define double precision with 15 digits of accuracy
! and an exponent range of +- 307
integer, parameter :: rk = selected_real_kind(8, 30)

integer  :: AllocateStatus     ! variable to hold memory allocation success
integer  :: i, j, q            ! loop iteration variables

integer  :: n_el               ! number of elements
integer  :: n_en               ! number of nodes per element
integer  :: n_nodes            ! total number of nodes
integer  :: order              ! polynomial order
integer  :: n_qp               ! number of quadrature points
integer  :: cnt                ! number of CG iterations
real(rk) :: length             ! length of the domain (1-D)
real(rk) :: h                  ! length of one element
real(rk) :: k                  ! thermal conductivity
real(rk) :: source             ! uniform heat source
real(rk) :: leftBC             ! left Dirichlet boundary condition value
real(rk) :: rightBC            ! right Dirichlet boundary condition value
real(rk) :: theta              ! conjugate gradient coefficient
real(rk) :: lambda             ! conjugate gradient coefficient
real(rk) :: convergence        ! difference between successive iterations
real(rk) :: tol                ! conjugate gradient convergence tolerance
real(rk) :: start              ! holds run times
real(rk) :: finish             ! holds run times
real(rk) :: startCL            ! start, command line parse
real(rk) :: endCL              ! end, command line parse
real(rk) :: startInit          ! start, initialization
real(rk) :: endInit            ! end, initialization
real(rk) :: startMem           ! start, memory allocation
real(rk) :: endMem             ! end, memory allocation
real(rk) :: startCG            ! start, CG
real(rk) :: endCG              ! end, CG
real(rk) :: m                  ! slope of line

integer,  dimension(:, :), allocatable :: LM     ! location matrix
integer,  dimension(:),    allocatable :: BCs    ! boundary condition nodes
real(rk), dimension(:),    allocatable :: qp     ! quadrature points
real(rk), dimension(:),    allocatable :: wt     ! quadrature weights
real(rk), dimension(:),    allocatable :: x      ! coordinates of the nodes
real(rk), dimension(:, :), allocatable :: kel    ! elemental stiffness matrix
real(rk), dimension(:),    allocatable :: rel    ! elemental load vector
real(rk), dimension(:, :), allocatable :: phi    ! shape functions
real(rk), dimension(:, :), allocatable :: dphi   ! shape function derivatives
real(rk), dimension(:),    allocatable :: rglob  ! global load vector
real(rk), dimension(:),    allocatable :: a      ! CG solution iterates
real(rk), dimension(:),    allocatable :: z      ! CG update iterates
real(rk), dimension(:),    allocatable :: res    ! solution residual
real(rk), dimension(:),    allocatable :: kelzprev    ! matrix-vector product

 

! initialize the thermal conductivity and heat source
k = 1.0
source = 1.0
tol = 0.001

call cpu_time(start)

call commandline(length, n_el, order, leftBC, rightBC) ! parse command line args
call initialize(h, x, n_en, n_el, order, n_nodes)      ! initialize problem vars

allocate(qp(n_qp), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of qp array failed."
allocate(wt(n_qp), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of wt array failed."

call quadrature(order, n_qp)                   ! initialize quadrature

allocate(phi(order + 1, n_qp), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of phi array failed."
allocate(dphi(order + 1, n_qp), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of dphi array failed."
allocate(kel(n_en, n_en), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of kel array failed."
allocate(rel(n_en), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of rel array failed."
allocate(LM(n_en, n_el), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of LM array failed."
allocate(BCs(2), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of BCs array failed."
allocate(rglob(n_nodes), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of rglob array failed."
allocate(a(n_nodes), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of a array failed."
allocate(z(n_nodes), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of z array failed."
allocate(res(n_nodes), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of res array failed."
allocate(kelzprev(n_nodes), stat = AllocateStatus)
if (AllocateStatus /= 0) STOP "Allocation of kelzprev array failed."

call phi_val(order, qp)                     ! initialize shape functions

! form the elemental stiffness matrix and load vector
kel = 0.0
rel = 0.0
do q = 1, n_qp
  do i = 1, n_en
    rel(i) = rel(i) + wt(q) * source * phi(i, q) * h *h / 2.0
    do j = 1, n_en
      kel(i, j) = kel(i, j) + wt(q) * dphi(i, q) * k * dphi(j, q) * 2.0
    end do
  end do
end do

! form the location matrix
call locationmatrix()

! determine the boundary condition nodes
BCs = (/1, n_nodes/)

! form the global load vector
! elements in LM are accessed by column (fastest)
rglob = 0.0
do q = 1, n_el
  do i = 1, n_en
    rglob(LM(i, q)) = rglob(LM(i, q)) + rel(i)
  end do
end do

! apply boundary conditions
rglob(1) = leftBC                ! left BC value
rglob(n_nodes) = rightBC         ! right BC value     

! initial guess is a straight line between the two endpoints
m = (rightBC - leftBC) / length
a = m * x
a = a + leftBC

call cpu_time(startCG)
call conjugategradient(a)
call cpu_time(endCG)
print *, 'CG iteration time: ', endCG - startCG

! write to an output file. If this file exists, it will be re-written.
open(1, file='output.txt', iostat=AllocateStatus, status="replace")
if (AllocateStatus /= 0) STOP "output.txt file opening failed."
write(1, *) a(:)

call cpu_time(finish)
print *, 'runtime: ', finish - start

open(2, file='timing.txt', status='old', action='write', &
  form='formatted', position='append')
write(2, *), n_el, finish - start, endCG - startCG, cnt

deallocate(qp, wt, x, kel, rel, phi, dphi, rglob, a, z, res, LM)

CONTAINS ! define all internal procedures

subroutine conjugategradient(a)
  real(8), intent(inout) :: a(:)
  res         = rglob - sparse_mult(kel, LM, a)
  z           = res
  lambda      = dotprod(z, res)/dotprod(z, sparse_mult(kel, LM, z))
  a           = a + lambda * z
  convergence = 0.0
  
  do i = 1, n_nodes
    convergence = convergence + abs(z(i))
  end do
  
  cnt = 0
  do while (lambda * convergence > tol)
    !kelzprev = sparse_mult(kel, LM, z) 

    res      = rglob - sparse_mult(kel, LM, a)
    theta    = sparse_mult_dot(kel, LM, z, res) / sparse_mult_dot(kel, LM, z, z)
    !theta    = dotprod(res, kelzprev) / dotprod(z, kelzprev)
    z        = res - theta * z
    lambda   = dotprod(z, res) / sparse_mult_dot(kel, LM, z, z)
    !lambda   = dotprod(z, res) / dotprod(z, sparse_mult(kel, LM, z))
    a        = a + lambda * z
  
    convergence = 0.0
    do i = 1, n_nodes
      convergence = convergence + abs(z(i))
    end do
    
  cnt = cnt + 1
  end do
end subroutine conjugategradient


integer function kronecker(i, j)
  integer :: i, j
  kronecker = int((float((i + j) - abs(i - j))) / (float((i + j) + abs(i - j))))
end function kronecker


real function dotprod(vec1, vec2)
  implicit none
  real(rk) :: vec1(:)
  real(rk) :: vec2(:)

  integer  :: i ! looping variable

  dotprod = 0.0  
  do i = 1, size(vec1)
    dotprod = dotprod + vec1(i) * vec2(i)
  end do
end function dotprod

function sparse_mult_dot(matrix, LM, vector, vecdot)
  implicit none
  real(rk) :: matrix(:, :) ! elementary matrix (assumed-shape array)
  real(rk) :: vector(:)    ! full vector (assumed-shape array)
  real(rk) :: vecdot(:)
  integer  :: LM(:, :)     ! location matrix
 
  ! return value of function
  real(rk) :: sparse_mult_dot
  integer  :: i, j, q ! looping variables
 
  sparse_mult_dot = 0.0
  do q = 1, n_el ! loop over the elements
    do i = 1, n_en ! loop over all entries in kel
      if (any(BCs == LM(i, q))) then 
        do j = 1, n_en
          sparse_mult_dot = sparse_mult_dot + vecdot(LM(i, q)) * kronecker(LM(i, q), LM(j, q)) * vector(LM(j, q))
        end do
      else
        ! implicitly assumes that the matrix is symmetric (ok for this application)
        do j = 1, n_en
          sparse_mult_dot = sparse_mult_dot + vecdot(LM(i, q)) * matrix(j, i) * vector(LM(j, q))
        end do
      end if
    end do
  end do
end function sparse_mult_dot


function sparse_mult(matrix, LM, vector)
  implicit none
  real(rk) :: matrix(:, :) ! elementary matrix (assumed-shape array)
  real(rk) :: vector(:)    ! full vector (assumed-shape array)
  integer  :: LM(:, :)     ! location matrix
 
  ! return value of function, as an automatic array
  real(rk) :: sparse_mult(size(vector))
  
  integer :: i, j, q ! looping variables
  sparse_mult = 0.0
   
  do q = 1, n_el ! loop over the elements
    do i = 1, n_en ! loop over all entries in kel
      if (any(BCs == LM(i, q))) then 
        do j = 1, n_en
          ! diagonal terms set to 1.0, off-diagonal set to 0.0
          sparse_mult(LM(i, q)) = sparse_mult(LM(i, q)) + &
                       kronecker(LM(i, q), LM(j, q)) * vector(LM(j, q))
        end do
      else
        do j = 1, n_en
          sparse_mult(LM(i, q)) = sparse_mult(LM(i, q)) + matrix(i, j) * vector(LM(j, q))
        end do
      end if
    end do
  end do
end function sparse_mult


subroutine locationmatrix()
  ! forms the location matrix, which is global in the calling program
  ! fills column-by-column (each column pertains to an element)
  implicit none
  integer :: i, j       ! looping variables
  
  do j = 1, n_el
    do i = 1, n_en
      LM(i, j) = (j - 1) * (n_en - 1) + i
    end do
  end do
end subroutine locationmatrix


subroutine phi_val(order, qp)
! populate phi and dphi, which are global to the calling program
  implicit none
  integer,  intent(in)  :: order
  real(rk), intent(in)  :: qp(:)

  select case(order)
    case(1)
      phi(1, :)  = (1.0 - qp(:)) / 2.0
      phi(2, :)  = (1.0 + qp(:)) / 2.0
      dphi(1, :) = -1.0 / 2.0
      dphi(2, :) =  1.0 / 2.0
    case(2)
      phi(1, :)  = qp(:) * (qp(:) - 1.0) / 2.0
      phi(2, :)  = (1.0 - qp(:)) * (1.0 + qp(:))
      phi(3, :)  = qp(:) * (qp(:) + 1.0) / 2.0
      dphi(1, :) = (2.0 * qp(:) - 1.0) / 2.0
      dphi(2, :) = 1.0 - qp(:) * qp(:)
      dphi(3, :) = (2.0 * qp(:) + 1.0) / 2.0
    case default
      write(*,*) "polynomial order not supported."
  end select
end subroutine phi_val


subroutine quadrature(order, n_qp)
  implicit none

  integer, intent(in)  :: order
  integer, intent(out) :: n_qp
  
  n_qp = 2
  !n_qp = ceiling((real(order) + 1.0) / 2.0)

  
  select case(n_qp)
    case(1)
      qp = (/ 0.0 /)
      wt = (/ 2.0 /)
    case(2)
      qp = (/ -1.0/sqrt(3.0), 1.0/sqrt(3.0) /)
      wt = (/ 1.0, 1.0 /)
    case(3)
      qp = (/ -sqrt(3.0/5.0), 0.0, sqrt(3.0/5.0) /)
      wt = (/ 5.0/9.0, 8.0/9.0, 5.0/9.0 /)
    case default
      write(*,*) "Error in selecting quadrature rule."
  end select
end subroutine quadrature


subroutine commandline(length, n_el, order, leftBC, rightBC)
  implicit none
  real(rk), intent(out) :: length
  integer, intent(out)  :: n_el
  integer, intent(out)  :: order
  real(rk), intent(out) :: leftBC
  real(rk), intent(out) :: rightBC
 
  integer :: nargs            ! number of command line arguments
  integer :: i                ! looping variable
  character(len = 12) :: args ! command line argument

  nargs = command_argument_count()

  do i = 1, nargs
    call get_command_argument(i, args)
  
    ! use internal reads to convert from character to numeric types
    ! (read from the character buffer into the numeric variable)
    select case (i)
      case(1)
        read(args, *) length  
      case(2)
        read(args, *) n_el
      case(3)
        read(args, *) order
      case(4)
        read(args, *) leftBC
      case(5)
        read(args, *) rightBC
      case default
        write(*,*) "Too many command line parameters."
    end select  
  enddo
end subroutine commandline


subroutine initialize(h, x, n_en, n_el, order, n_nodes)
  implicit none
  real(rk), intent(out) :: h 
  integer, intent(out) :: n_en    
  integer, intent(in)  :: n_el    
  integer, intent(in)  :: order   
  integer, intent(out) :: n_nodes 
  real (rk), dimension(:), allocatable, intent(out) :: x 

  integer :: i ! looping variable

  h = length / real(n_el)
  n_en = order + 1
  n_nodes = (order + 1) * n_el - (n_el - 1)
   
  ! allocate memory for the vector of node coordinates
  allocate(x(n_nodes), stat = AllocateStatus)
  if (AllocateStatus /= 0) STOP "Allocation of x array failed."

  ! loop is vectorized, estimated speedup: 3.47
  ! changed from two type converts to only one
  do i = 1, size(x)
    x(i) = real(i - 1) * h / real(n_en - 1)
  end do
end subroutine initialize


END PROGRAM main
