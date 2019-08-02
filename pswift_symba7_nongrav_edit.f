c**********************************************************************
c         SWIFT_SYMBA7.F
c**********************************************************************
c
c                 To run, need 2 input files. The code prompts for
c                 the file names, but examples are :
c
c                   parameter file like       param.in
c       planet file like          pl.in
c
c  NOTE:  No test particles in this code and the massive bodies
c         are dimensioned at NTPMAX
c
c Authors:  Hal Levison \& Martin Duncan
c Date:    11/21/96
c Last revision: 12/27/96


      include '../swift.inc'

      real*8 mass(NTPMAX),j2rp2,j4rp4
      real*8 xh(NTPMAX),yh(NTPMAX),zh(NTPMAX)
      real*8 vxh(NTPMAX),vyh(NTPMAX),vzh(NTPMAX)

      real*8 xht(1),yht(1),zht(1)       ! Dummy for the io
      real*8 vxht(1),vyht(1),vzht(1)
      integer ntp,istat(1)

      integer nbod,i1st,i,nbodm,nbodo
      integer iflgchk,iub,iuj,iud,iue,ium

      real*8 t0,tstop,dt,dtout,dtdump
      real*8 t,tout,tdump,tfrac,eoff
      real*8 rpl(NTPMAX),rhill(NTPMAX)

      real*8 rmin,rmax,rmaxu,qmin,mtiny
      real*8 ke,pot,energy,eltot(3)
      logical*2 lclose
      integer isenc,ihills
      integer mergelst(2,NTPMAX),mergecnt
      integer*2 iecnt(NTPMAX)

      character*80 outfile,inparfile,inplfile,fopenstat

c...  OMP stuff
!$    logical OMP_get_dynamic
!$    integer nthreads,OMP_get_max_threads

      real*4 tarray(2), etime, tcpu
c-----
c...  Executable code

      ntp = 0

c...  print version number
      call util_version

c...  OMP stuff
!$    write(*,*) 'Dynamic thread allocation: ',OMP_get_dynamic()
!$    nthreads = OMP_get_max_threads() ! In the *parallel* case
!$    write(*,'(a)')      ' OpenMP parameters:'
!$    write(*,'(a)')      ' ------------------'
!$    write(*,'(a,i3,/)') ' Number of threads  = ', nthreads

c Get data for the run and the test particles
      write(*,*) 'Enter name of parameter data file : '
      read(*,999) inparfile
      call io_init_param(inparfile,t0,tstop,dt,dtout,dtdump,
     &     iflgchk,rmin,rmax,rmaxu,qmin,lclose,outfile,fopenstat)

c Prompt and read name of planet data file
      write(*,*) ' '
      write(*,*) 'Enter name of planet data file : '
      read(*,999) inplfile
 999  format(a)
      call io_init_pl_symba(inplfile,lclose,iflgchk,nbod,mass,
     &     xh,yh,zh,vxh,vyh,vzh,rpl,rhill,j2rp2,j4rp4)

      write(*,*) 'Enter the smallest mass to self gravitate :'
      read(*,*) mtiny
      write(*,*) ' mtiny = ',mtiny

c Initialize initial time and times for first output and first dump
      t = t0
      tout = t0 + dtout
      tdump = t0 + dtdump

      iub = 20
      iuj = 30
      iud = 40
      iue = 60
      ium = 21

c...    Do the initial io write
      if(btest(iflgchk,0))  then ! bit 0 is set
         call io_write_frame(t0,nbod,ntp,mass,xh,yh,zh,vxh,vyh,vzh,
     &        xht,yht,zht,vxht,vyht,vzht,istat,outfile,iub,fopenstat)
         call io_write_mass(t0,nbod,mass,outfile,ium,fopenstat)
      endif
      if(btest(iflgchk,1))  then ! bit 1 is set
         call io_write_frame_r(t0,nbod,ntp,mass,xh,yh,zh,vxh,vyh,vzh,
     &        xht,yht,zht,vxht,vyht,vzht,istat,outfile,iub,fopenstat)
         call io_write_mass_r(t0,nbod,mass,outfile,ium,fopenstat)
      endif

c...  must initize discard io routine
      if(btest(iflgchk,4))  then ! bit 4 is set
         call io_discard_mass(0,t,0,mass(1),rpl(1),xh(1),yh(1),zh(1),
     &        vxh(1),vyh(1),vzh(1),iud,-1,fopenstat)
      endif

c...  Calculate the location of the last massive particle
      call symba7_nbodm(nbod,mass,mtiny,nbodm)

c...  set up energy write stuff
      if(btest(iflgchk,2))  then ! bit 2 is set
         eoff = 0.0d0
         call anal_energy_write(t0,nbod,mass,j2rp2,j4rp4,xh,yh,zh,vxh,
     &        vyh,vzh,iue,fopenstat,eoff)
         call anal_energy_discard5(1,nbod,nbodm,mass,j2rp2,j4rp4,
     &        xh,yh,zh,vxh,vyh,vzh,ke,pot,energy,eltot)
      else
         call anal_energy_discard5(-1,nbod,nbodm,mass,j2rp2,j4rp4,
     &        xh,yh,zh,vxh,vyh,vzh,ke,pot,energy,eltot)
      endif

      ihills = 0
      i1st = 0

      tcpu=0.
c***************here's the big loop *************************************
      write(*,*) ' ************** MAIN LOOP ****************** '

      do while ( (t .le. tstop) .and. (nbod.gt.1))

      write(*,*)"made it here: ",t

         call symba7_step_pl(i1st,t,nbod,nbodm,mass,j2rp2,j4rp4,
     &        xh,yh,zh,vxh,vyh,vzh,dt,lclose,rpl,isenc,
     &        mergelst,mergecnt,iecnt,eoff,rhill,mtiny)

      write(*,*)"made it here: ",t

         t = t + dt

         if(btest(iflgchk,4))  then ! bit 4 is set
            nbodo = nbod
            call discard_massive5(t,dt,nbod,mass,xh,yh,zh,
     &           vxh,vyh,vzh,rmin,rmax,rmaxu,qmin,lclose,
     &           rpl,rhill,isenc,mergelst,mergecnt,
     &           iecnt,eoff,i1st)
            if(nbodo.ne.nbod) then
               call symba7_nbodm(nbod,mass,mtiny,nbodm)
            endif
         endif


c if it is time, output orb. elements,
         if(t .ge. tout) then

            if(btest(iflgchk,0))  then ! bit 0 is set
               call  io_write_frame(t,nbod,ntp,mass,xh,yh,zh,vxh,
     &              vyh,vzh,xht,yht,zht,vxht,vyht,vzht,istat,outfile,
     &              iub,fopenstat)
               call io_write_mass(t,nbod,mass,outfile,ium,fopenstat)
            endif
            if(btest(iflgchk,1))  then ! bit 1 is set
               call  io_write_frame_r(t,nbod,ntp,mass,xh,yh,zh,vxh,
     &              vyh,vzh,xht,yht,zht,vxht,vyht,vzht,istat,outfile,
     &              iub,fopenstat)
               call io_write_mass_r(t,nbod,mass,outfile,ium,fopenstat)
            endif

      tout = tout + dtout
         endif

c If it is time, do a dump
         if(t.ge.tdump) then

            tfrac = (t-t0)/(tstop-t0)
            write(*,998) t,tfrac,nbod
 998        format(' Time = ',1p1e12.5,': fraction done = ',0pf5.3,
     &            ': Number of bodies =',i4)
            call io_dump_pl_symba('dump_pl.dat',nbod,mass,xh,yh,zh,
     &           vxh,vyh,vzh,lclose,iflgchk,rpl,rhill,j2rp2,j4rp4)
            call io_dump_param('dump_param.dat',t,tstop,dt,dtout,
     &           dtdump,iflgchk,rmin,rmax,rmaxu,qmin,lclose,outfile)
            tdump = tdump + dtdump

            if(btest(iflgchk,2))  then ! bit 2 is set
               call anal_energy_write(t,nbod,mass,j2rp2,j4rp4,
     &              xh,yh,zh,vxh,vyh,vzh,iue,fopenstat,eoff)
            endif

      endif

      tcpu=etime(tarray)

      enddo
c********** end of the big loop from time 't0' to time 'tstop'

c Do a final dump for possible resumption later

      call io_dump_pl_symba('dump_pl.dat',nbod,mass,xh,yh,zh,
     &            vxh,vyh,vzh,lclose,iflgchk,rpl,rhill,j2rp2,j4rp4)
      call io_dump_param('dump_param.dat',t,tstop,dt,dtout,
     &         dtdump,iflgchk,rmin,rmax,rmaxu,qmin,lclose,outfile)

        call util_exit(0)
        end    ! swift_symba7.f
c---------------------------------------------------------------------

c*************************************************************************
c                            SYMBA7_STEP_INTERP.F
c*************************************************************************
c
c             Input:
c                 time          ==> Current time (real scalar)
c                 iecnt         ==>  The number of objects that each planet
c                                    is encountering (int*2 array)
c                 ielev         ==>  The level that this particle should go
c                                             (int*2 array)
c                 nbod          ==>  number of massive bodies (int scalar)
c                 nbodm         ==>  Location of last massive body(int scalar)
c                 mass          ==>  mass of bodies (real array)
c                 rhill         ==>  Radius of hill sphere (real array)
c                 j2rp2,j4rp4   ==>  J2*radii_pl^2 and  J4*radii_pl^4
c                                     (real scalars)
c                 xh,yh,zh      ==>  initial position in helio coord
c                                    (real arrays)
c                 vxh,vyh,vzh   ==>  initial velocity in helio coord
c                                    (real arrays)
c                 dt            ==>  time step
c                 lclose        ==> .true. --> marge particles if they
c                                    get too close. Read in that
c                                    distance in io_init_pl
c                                      (logical*2 scalar)
c                 rpl           ==>  physical size of a planet.
c                                    (real array)
c                 eoff          ==>  Energy offset (real scalar)
c                ielc           ==>  number of encounters (integer*2 scalar)
c                ielst          ==>  list of ecnounters (2D integer*2 array)
c                mtiny          ==>  Small mass  (real array)
c             Output:
c                 xh,yh,zh      ==>  final position in helio coord
c                                       (real arrays)
c                 vxh,vyh,vzh   ==>  final velocity in helio coord
c                                       (real arrays)
c                 rpl           ==>  Recalculated physical size of a planet.
c                                    if merger happened (real array)
c                 nbod          ==>  Recalculated number of massive bodies
c                                    if merger happened (int scalar)
c                 nbodm         ==>  Location of last massive body(int scalar)
c                 mass          ==>  Recalculated mass of bodies
c                                    if merger happened (real array)
c                 mergelst      ==>  list of mergers (int array)
c                 mergecnt      ==>  count of mergers (int array)
c                 eoff          ==>  Energy offset (real scalar)
c Remarks:
c Authors:  Hal Levison
c Date:    11/21/96
c Last revision: 5/13/99

      subroutine symba7_step_interp(time,iecnt,ielev,nbod,
     &     nbodm,mass,rhill,j2rp2,j4rp4,lclose,rpl,xh,yh,zh,vxh,
     &     vyh,vzh,dt,mergelst,mergecnt,eoff,ielc,ielst,mtiny)

      include '../swift.inc'
      include 'symba7.inc'

c...  Inputs Only:
      real*8 mass(NTPMAX),dt,j2rp2,j4rp4,time,mtiny
      integer*2 iecnt(NTPMAX),ielev(NTPMAX)
      logical*2 lclose
      integer*2 ielst(2,NENMAX),ielc

c...  Inputs and Outputs:
      integer nbod,nbodm
      real*8 xh(nbod),yh(nbod),zh(nbod)
      real*8 vxh(nbod),vyh(nbod),vzh(nbod)
      real*8 rpl(nbod),eoff
      real*8 rhill(nbod)

c...  Outputs
      integer mergelst(2,NTPMAX),mergecnt

c...  Internals:
      integer irec,ilevl(NTPMAX),i
      real*8 dth
      real*8 axh(NTPMAX),ayh(NTPMAX),azh(NTPMAX)
      real*8 vxb(NTPMAX),vyb(NTPMAX),vzb(NTPMAX),msys
      real*8 ptxb,ptyb,ptzb            ! Not used here
      real*8 ptxe,ptye,ptze
      logical*1 svdotr(NENMAX)  ! Used by symba_step_recur

      save axh,ayh,azh     ! Note this !!
      save vxb,vyb,vzb     ! Note this !!

c----
c...  Executable code

      dth = 0.5d0*dt

c     changes the velocities according to tides
      call tidal_kick(nbod,nbodm,mass,xh,yh,zh,vxh,vyh
     &     ,vzh,dth)

c...  Convert vel to bery to jacobi coords
      call coord_vh2b(nbod,mass,vxh,vyh,vzh,vxb,vyb,vzb,msys)

c...  Do the linear drift due to momentum of the Sun
      call helio_lindrift(nbod,mass,vxb,vyb,vzb,dth,
     &     xh,yh,zh,ptxb,ptyb,ptzb)

c...  Get the accelerations in helio frame. For each object
c...     only include those guys that it is not encountering with.
      call symba7_getacch(nbod,nbodm,mass,j2rp2,j4rp4,
     &     xh,yh,zh,axh,ayh,azh,mtiny,ielc,ielst)

c...  Apply a heliocentric kick for a half dt
      call kickvh(nbod,vxb,vyb,vzb,axh,ayh,azh,dth)

c..   Do a recursion step for full dt
      irec = -1
      call symba7_helio_drift(nbod,ielev,irec,mass,xh,
     &     yh,zh,vxb,vyb,vzb,dt)
      irec = 0
      do i=2,nbod
         ilevl(i) = 0
      enddo
      mergecnt = 0
      call symba7_step_recur(time,nbod,nbodm,mass,irec,ilevl,
     &     iecnt,ielev,rhill,xh,yh,zh,vxb,vyb,vzb,lclose,
     &     rpl,mergelst,mergecnt,dt,eoff,svdotr,ielc,ielst)

c...  Get the accelerations in helio frame. For each object
c...     only include those guys that it is not encountering with.
      call symba7_getacch(nbod,nbodm,mass,j2rp2,j4rp4,
     &     xh,yh,zh,axh,ayh,azh,mtiny,ielc,ielst)

c...  Apply a heliocentric kick for a half dt
      call kickvh(nbod,vxb,vyb,vzb,axh,ayh,azh,dth)

c...  Do the linear drift due to momentum of the Sun
      call helio_lindrift(nbod,mass,vxb,vyb,vzb,dth,
     &     xh,yh,zh,ptxe,ptye,ptze)

c...  convert back to helio velocities
      call coord_vb2h(nbod,mass,vxb,vyb,vzb,vxh,vyh,vzh)

c     changes the velocities according to tides
      call tidal_kick(nbod,nbodm,mass,xh,yh,zh,vxh,vyh
     &     ,vzh,dth)

      return
      end   ! symba7_step_interp
c---------------------------------------------------------------------

      subroutine gasdrag_kick(nbod,nbodm,mass,xh,yh,zh,vxh,vyh
     &     ,vzh,dt)

      include 'swift.inc'
c this version deals with gasdrag and tidal e/i damping, using the gas
c profile provided by Morby&Crida Jupiter-Saturn simulation
c updated dec 8, 2009.


c...  Inputs Only:
      integer nbod,nbodm
      real*8 dt
      real*8 t,xh(nbod),yh(nbod),zh(nbod),mass(nbod)

c...  Inputs and Output:
      real*8 vxh(nbod),vyh(nbod),vzh(nbod)

c...  Internals:
      integer i,id,i1st,iten,j
      real*8 axh(nbod),ayh(nbod),azh(nbod)

c    Insert code here to calculate accelerations


c    Accelerations are added to velocities here
      do i=2,nbod
         vxh(i) = vxh(i) + axh(i)*dt
         vyh(i) = vyh(i) + ayh(i)*dt
         vzh(i) = vzh(i) + azh(i)*dt
      enddo


      end