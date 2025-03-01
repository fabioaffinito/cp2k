!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2022 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Some auxiliary functions and subroutines needed for HFX calculations
!> \par History
!>      04.2008 created [Manuel Guidon]
!> \author Manuel Guidon
! **************************************************************************************************
MODULE hfx_helpers
#include "./base/base_uses.f90"
   IMPLICIT NONE
   PRIVATE

   PUBLIC :: count_cells_perd, &
             next_image_cell_perd

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'hfx_helpers'

!***

CONTAINS

! **************************************************************************************************
!> \brief - Auxiliary function for creating periodic neighbor cells
!> \param shell number of shells in each coordinate direction
!> \param perd ...
!> \return ...
!> \par History
!>      09.2007 created [Manuel Guidon]
!> \author Manuel Guidon
! **************************************************************************************************
   FUNCTION count_cells_perd(shell, perd)
      INTEGER, INTENT(IN)                                :: shell, perd(3)
      INTEGER                                            :: count_cells_perd

      INTEGER                                            :: i, j, k

      count_cells_perd = 0
      DO i = -shell*perd(1), shell*perd(1)
         DO j = -shell*perd(2), shell*perd(2)
            DO k = -shell*perd(3), shell*perd(3)
               IF ((i**2 + j**2 + k**2 == shell)) count_cells_perd = count_cells_perd + 1
            END DO
         END DO
      END DO
   END FUNCTION count_cells_perd

! **************************************************************************************************
!> \brief - Auxiliary function for creating periodic neighbor cells
!> \param m ...
!> \param perd ...
!> \par History
!>      09.2007 created [Manuel Guidon]
!> \author Manuel Guidon
! **************************************************************************************************
   SUBROUTINE next_image_cell_perd(m, perd)
      INTEGER                                            :: m(3)
      INTEGER, INTENT(IN)                                :: perd(3)

      INTEGER                                            :: i, j, k, shell
      LOGICAL                                            :: found

      found = .FALSE.
      shell = SUM(m**2)
      outer: DO
         DO i = -shell*perd(1), shell*perd(1)
         DO j = -shell*perd(2), shell*perd(2)
            inner: DO k = -shell*perd(3), shell*perd(3)
               IF (.NOT. (i**2 + j**2 + k**2 == shell)) CYCLE inner
               IF (found) THEN
                  m = (/i, j, k/)
                  EXIT outer
               END IF
               IF (ALL(M .EQ. (/i, j, k/))) found = .TRUE.
            END DO inner
         END DO
         END DO
         shell = shell + 1
      END DO outer
   END SUBROUTINE next_image_cell_perd

! **************************************************************************************************

END MODULE hfx_helpers
