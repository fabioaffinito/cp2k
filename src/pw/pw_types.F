!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2022 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \note
!>      If parallel mode is distributed certain combination of
!>      "in_use" and "in_space" can not be used.
!>      For performance reasons it would be better to have the loops
!>      over g-vectros in the gather/scatter routines in new subprograms
!>      with the actual arrays (also the addressing) in the parameter list
!> \par History
!>      JGH (29-Dec-2000) : Changes for parallel use
!>      JGH (13-Mar-2001) : added timing calls
!>      JGH (26-Feb-2003) : OpenMP enabled
!>      JGH (17-Nov-2007) : Removed mass arrays
!>      JGH (01-Dec-2007) : Removed and renamed routines
!>      03.2008 [tlaino] : Splitting pw_types into pw_types and pw_methods
!> \author apsi
! **************************************************************************************************
MODULE pw_types

   USE cp_log_handling,                 ONLY: cp_get_default_logger,&
                                              cp_logger_get_default_unit_nr,&
                                              cp_logger_type,&
                                              cp_to_string
   USE kinds,                           ONLY: dp
   USE pw_grid_types,                   ONLY: pw_grid_type
   USE pw_grids,                        ONLY: pw_grid_release,&
                                              pw_grid_retain
   USE timings,                         ONLY: print_stack
#include "../base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE
   PUBLIC :: pw_type, pw_p_type
   PUBLIC :: pw_release, pw_create

   ! Flags for the structure member 'in_use'
   INTEGER, PARAMETER, PUBLIC :: REALDATA1D = 301, COMPLEXDATA1D = 302
   INTEGER, PARAMETER, PUBLIC :: REALDATA3D = 303, COMPLEXDATA3D = 304, NODATA = 305

   ! Flags for the structure member 'in_space'
   INTEGER, PARAMETER, PUBLIC :: NOSPACE = 371, REALSPACE = 372, RECIPROCALSPACE = 373
   INTEGER, PUBLIC, PARAMETER :: SQUARE = 391, SQUAREROOT = 392

   ! to generate unique id_nr
   INTEGER, SAVE, PRIVATE :: last_pw_id_nr = 0

! **************************************************************************************************
   TYPE pw_type
      REAL(KIND=dp), DIMENSION(:), CONTIGUOUS, POINTER :: cr => NULL()
      REAL(KIND=dp), DIMENSION(:, :, :), CONTIGUOUS, POINTER :: cr3d => NULL()
      COMPLEX(KIND=dp), DIMENSION(:), CONTIGUOUS, POINTER :: cc => NULL()
      COMPLEX(KIND=dp), DIMENSION(:, :, :), CONTIGUOUS, POINTER :: cc3d => NULL()

      INTEGER :: in_use = NODATA ! Which data is used [r1d/c1d/r3d/c3d]
      INTEGER :: in_space = NOSPACE ! Real/Reciprocal space
      INTEGER :: id_nr = -1 ! unique identifier

      TYPE(pw_grid_type), POINTER :: pw_grid => NULL()
   END TYPE pw_type

! **************************************************************************************************
   TYPE pw_p_type
      TYPE(pw_type), POINTER :: pw => NULL()
   END TYPE pw_p_type

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'pw_types'
   LOGICAL, PARAMETER, PRIVATE :: debug_this_module = .FALSE.

CONTAINS

! **************************************************************************************************
!> \brief releases the given pw
!> \param pw the pw to release
!> \par History
!>      04.2003 created [fawzi]
!> \author fawzi
!> \note
!>      see doc/ReferenceCounting.html
! **************************************************************************************************
   SUBROUTINE pw_release(pw)
      TYPE(pw_type), INTENT(INOUT)                       :: pw

      SELECT CASE (pw%in_use)
      CASE (REALDATA1D)
         DEALLOCATE (pw%cr)
      CASE (COMPLEXDATA1D)
         DEALLOCATE (pw%cc)
      CASE (REALDATA3D)
         IF (ASSOCIATED(pw%cr3d)) THEN
            !FM optimizations of pools might have removed the 3d field to cache it
            DEALLOCATE (pw%cr3d)
         END IF
      CASE (COMPLEXDATA3D)
         DEALLOCATE (pw%cc3d)
      CASE (NODATA)
      CASE default
         CPABORT("unknown data type "//cp_to_string(pw%in_use))
      END SELECT
      CALL pw_grid_release(pw%pw_grid)
   END SUBROUTINE pw_release

! **************************************************************************************************
!> \brief allocates and initializes pw_type
!> \param pw the type that will bw allocated and initialized
!> \param pw_grid ...
!> \param use_data which kind of data will be used
!> \param in_space in which space the pw is (real or reciprocal)
!> \param cr3d_ptr pointer with the cr3d data (make sense only if
!>        use_data==REALDATA3D)
!> \par History
!>      11.2003 created [fawzi]
!> \author fawzi
! **************************************************************************************************
   SUBROUTINE pw_create(pw, pw_grid, use_data, in_space, cr3d_ptr)
      TYPE(pw_type), INTENT(OUT)                         :: pw
      TYPE(pw_grid_type), INTENT(IN), POINTER            :: pw_grid
      INTEGER, INTENT(in)                                :: use_data
      INTEGER, INTENT(in), OPTIONAL                      :: in_space
      REAL(KIND=dp), CONTIGUOUS, DIMENSION(:, :, :), &
         INTENT(IN), OPTIONAL, POINTER                   :: cr3d_ptr

      CHARACTER(len=*), PARAMETER                        :: routineN = 'pw_create'

      INTEGER                                            :: handle
      INTEGER, DIMENSION(:, :), POINTER                  :: bounds
      TYPE(cp_logger_type), POINTER                      :: logger

      CALL timeset(routineN, handle)
      logger => cp_get_default_logger()
      IF (debug_this_module) THEN
         WRITE (cp_logger_get_default_unit_nr(logger), "('*** allocated pw ***')")
         IF (PRESENT(cr3d_ptr)) THEN
            IF (ASSOCIATED(cr3d_ptr)) THEN
               WRITE (cp_logger_get_default_unit_nr(logger), "('*** cr3d associated ***')")
            END IF
         END IF
         CALL print_stack(cp_logger_get_default_unit_nr(logger))
      END IF

      IF (PRESENT(cr3d_ptr)) THEN
         IF (ASSOCIATED(cr3d_ptr)) THEN
            CPASSERT(use_data == REALDATA3D)
         END IF
      END IF

      last_pw_id_nr = last_pw_id_nr + 1
      pw%id_nr = last_pw_id_nr
      pw%in_use = use_data
      pw%pw_grid => pw_grid
      CALL pw_grid_retain(pw%pw_grid)
      pw%in_space = NOSPACE
      bounds => pw%pw_grid%bounds_local

      SELECT CASE (use_data)
      CASE (REALDATA1D)
         ALLOCATE (pw%cr(pw%pw_grid%ngpts_cut_local))

      CASE (COMPLEXDATA1D)
         ALLOCATE (pw%cc(pw%pw_grid%ngpts_cut_local))

      CASE (REALDATA3D)
         IF (PRESENT(cr3d_ptr)) THEN
            IF (ASSOCIATED(cr3d_ptr)) THEN
               IF (ALL(bounds(1, :) <= bounds(2, :))) THEN
                  CPASSERT(ALL(LBOUND(cr3d_ptr) == bounds(1, :)))
                  CPASSERT(ALL(UBOUND(cr3d_ptr) == bounds(2, :)))
               END IF
               pw%cr3d => cr3d_ptr
            END IF
         END IF
         IF (.NOT. ASSOCIATED(pw%cr3d)) THEN
            ALLOCATE (pw%cr3d( &
                      bounds(1, 1):bounds(2, 1), &
                      bounds(1, 2):bounds(2, 2), &
                      bounds(1, 3):bounds(2, 3)))
         END IF

      CASE (COMPLEXDATA3D)
         ALLOCATE (pw%cc3d( &
                   bounds(1, 1):bounds(2, 1), &
                   bounds(1, 2):bounds(2, 2), &
                   bounds(1, 3):bounds(2, 3)))
      CASE (NODATA)
      CASE default
         CPABORT("unknown data type")
      END SELECT
      IF (PRESENT(in_space)) pw%in_space = in_space
      CALL timestop(handle)
   END SUBROUTINE pw_create

END MODULE pw_types
