# ==================================================================================
# Model Description
# Application: Griffin
# Idaho National Lab (INL), Idaho Falls, October 17, 2022
# Author: Adam Zabriskie, INL
# ==================================================================================
# TREAT Griffin Transient Pulse Initial Conditions
# SubApp
# ==================================================================================
# This model has been built based on [1]
# If using or referring to this model, please cite as explained in
# https://mooseframework.inl.gov/virtual_test_bed/citing.html
# ----------------------------------------------------------------------------------
# [1] Zabriskie, A. X. (2019). Multi-Scale, Multi-Physics Reactor Pulse Simulation
#       Method with Macroscopic and Microscopic Feedback Effects (Unpublished
#       doctoral dissertation). Oregon State University, Corvallis, Oregon.
# ==================================================================================

# ==================================================================================
# Optional Debugging block
# ==================================================================================

[Debug]
  #  show_actions = true          #True prints out actions
  #  show_material_props = true   #True prints material properties
  #  show_parser = true
  #  show_top_residuals = 3        #Number to print
  #  check_boundary_coverage = true
  #  print_block_volume = true
  #  show_neutronics_material_coverage = true
  #  show_petsc_options = true
  # show_var_residual_norms = true
[]

# ==================================================================================
# Geometry and Mesh
# ==================================================================================

[Mesh]
  # Simple Reflected Cube Reactor
  # Start at zero, half core length reflector thickness; 1/8th symmetric
  # Element size: reflector 5.08 cm and core 4.827616834 cm
  # 14 in half-core, 12 in reflector
  [init_mesh]
    type = CartesianMeshGenerator
    dim = 3
    dx = '67.58663568 60.96'
    dy = '67.58663568 60.96'
    dz = '67.58663568 60.96'
    ix = '14 12'
    iy = '14 12'
    iz = '14 12'
  []
  [set_core_id]
    type = SubdomainBoundingBoxGenerator
    block_id =  10
    input = init_mesh
    bottom_left = '0.0 0.0 0.0'
    top_right = '67.58663568 67.58663568 67.58663568'
  []
[]

# ==================================================================================
# Transport Systems
# ==================================================================================

[TransportSystems]
  # In 3D, back = 0, bottom = 1, right = 2, top = 3, left = 4, front = 5
  # back is -z, bottom is -y, right is +x
  #Boundary Conditions#
  G =  6
  ReflectingBoundary = '0 1 4'
  VacuumBoundary = '2 3 5'
  equation_type = eigenvalue
  for_adjoint = false
  particle = neutron
  [diffing]
    family = LAGRANGE
    n_delay_groups =  6
    order = FIRST
    scheme = CFEM-Diffusion
  []
[]

# ==================================================================================
# Auxilliary Variables and Auxilliary Kernels
# ==================================================================================

[AuxVariables]
  [temperature]
    family = LAGRANGE
    initial_condition =  300.0
    order = FIRST
  []
  [Boron_Conc]
    family = MONOMIAL
    initial_condition = 1.89489259748
    order = CONSTANT
  []
  [PowerDensity]
    block = '10'
    family = MONOMIAL
    order = CONSTANT
  []
  [avg_coretemp]
    block = 0
    family = LAGRANGE
    initial_condition =  300.0
    order = FIRST
  []
[]
[AuxKernels]
  [PowerDensityCalc]
    type = VectorReactionRate
    block = '10'
    cross_section = kappa_sigma_fission
    dummies = UnscaledTotalPower
    execute_on = 'initial linear'
    scalar_flux =  'sflux_g0 sflux_g1 sflux_g2 sflux_g3 sflux_g4 sflux_g5'
    scale_factor = PowerScaling
    variable = PowerDensity
  []
  [Set_coreT]
    type = SetAuxByPostprocessor
    block = 0
    execute_on = 'linear timestep_end'
    postproc_value = avg_coretemp
    variable = avg_coretemp
  []
[]

# ==================================================================================
# Postprocessor Values
# ==================================================================================

[Postprocessors]
  [UnscaledTotalPower]
    type = FluxRxnIntegral
    block = 10
    coupled_flux_groups = 'sflux_g0 sflux_g1 sflux_g2 sflux_g3 sflux_g4 sflux_g5'
    cross_section = kappa_sigma_fission
    execute_on = linear
  []
  [PowerScaling]
    # 100 kW for entire TREAT
    type = PowerModulateFactor
    execute_on = linear
    power_pp = UnscaledTotalPower
    rated_power =  12500.0  []
  [avg_coretemp]
    type = ElementAverageValue
    block = 10
    execute_on = linear
    outputs = all
    variable = temperature
  []
  [avg_refltemp]
    type = ElementAverageValue
    block = 0
    execute_on = linear
    outputs = all
    variable = temperature
  []
  [avg_powerden]
    type = ElementAverageValue
    block = 10
    execute_on = timestep_end
    outputs = all
    variable = PowerDensity
  []
  [ScaledTotalPower]
    type = ElementIntegralVariablePostprocessor
    block = 10
    execute_on = linear
    variable = PowerDensity
  []
  [delta_time]
    type = TimestepSize
  []
  [nl_steps]
    type = NumNonlinearIterations
  []
  [lin_steps]
    type = NumLinearIterations
  []
  [Eq_TREAT_Power]
    type = ScalePostprocessor
    scaling_factor =  2469860.77609
    value = avg_powerden
  []
[]

# ==================================================================================
# Materials
# ==================================================================================

[Materials]
  [neut_mix]
    type = CoupledFeedbackNeutronicsMaterial
    block = 10
    densities =  '0.998448391539 0.00155160846058'
    grid_names = 'Tfuel Tmod Rod'
    grid_variables = 'temperature temperature Boron_Conc'
    isotopes =  'pseudo1 pseudo2'
    library_file = 'cross_sections/leu_20r_is_6g_d.xml'
    library_name = leu_20r_is_6g_d
    material_id = 1
    plus = true
  []
  [kth]
    # Volume weighted harmonic mean
    # Divided fg_kth by 100 to get it into cm
    type = ParsedMaterial
    coupled_variables =  'temperature'
    block = 10
    constant_expressions =  '3.35103216383e-08 1.31125888571e-07 2.14325144175e-05 0.3014 0.01046 1.0 0.05 1.5 1.0'
    constant_names = 'vol_fg vol_fl vol_gr gr_kth fl_kth beta p_vol sigma kap3x'
    property_name =  'thermal_conductivity'
    expression =  'lt := temperature / 1000.0; fresh := (100.0 / (6.548 + 23.533 * lt) + 6400.0 * exp(-16.35 / lt) / pow(lt, 5.0/2.0)) / 100.0; kap1d := (1.09 / pow(beta, 3.265) + 0.0643 * sqrt(temperature) / sqrt(beta)) * atan(1.0 / (1.09 / pow(beta, 3.265) + sqrt(temperature) * 0.0643 / sqrt(beta))); kap1p := 1.0 + 0.019 * beta / ((3.0 - 0.019 * beta) * (1.0 + exp(-(temperature - 1200.0) / 100.0))); kap2p := (1.0 - p_vol) / (1.0 + (sigma - 1.0) * p_vol); kap4r := 1.0 - 0.2 / (1.0 + exp((temperature - 900.0) / 80.0)); fg_kth := fresh * kap1d * kap1p * kap2p * kap3x * kap4r; (vol_fg + vol_fl + vol_gr) / (vol_fg / fg_kth + vol_fl / fl_kth + vol_gr / gr_kth)'
  []
  [rho_cp]
    # Volume weighted arithmetic mean (Irradiation has no effect)
    type = ParsedMaterial
    coupled_variables =  'temperature'
    block = 10
    constant_expressions =  '3.35103216383e-08 2.1563640306e-05 0.0018 0.010963'
    constant_names =  'vol_fg vol_gr rho_gr rho_fg'
    property_name =  'heat_capacity'
    expression = 'lt := temperature / 1000.0; gr_rhocp := rho_gr / (11.07 * pow(temperature, -1.644) + 0.0003688 * pow(temperature, 0.02191)); fink_cp := 52.1743 + 87.951 * lt - 84.2411 * pow(lt, 2) + 31.542 * pow(lt, 3) - 2.6334 * pow(lt, 4) - 0.71391 * pow(lt, -2); fg_rhocp := rho_fg * fink_cp / 267.2 * 1000.0; (vol_fg * fg_rhocp + vol_gr * gr_rhocp) / (vol_fg + vol_gr)'
  []
  [neut_refl]
    type = CoupledFeedbackNeutronicsMaterial
    block = 0
    densities = '1'
    grid_names = 'Trefl Tcore Rod'
    grid_variables = 'temperature avg_coretemp Boron_Conc'
    isotopes = 'pseudo'
    library_file = 'cross_sections/leu_macro_6g.xml'
    library_name = leu_macro_6g
    material_id = 2
    plus = true
  []
  [ref_kth]
    type = GenericConstantMaterial
    block = 0
    prop_names = 'thermal_conductivity'
    prop_values =  '0.3014'
  []
  [ref_rho_cp]
    type = ParsedMaterial
    coupled_variables =  'temperature'
    block = '0'
    constant_expressions =  '0.0018'
    constant_names = 'rho_gr'
    property_name =  'heat_capacity'
    expression =  'rho_gr / (11.07 * pow(temperature, -1.644) + 0.0003688 * pow(temperature, 0.02191))'
  []
[]

# ==================================================================================
# Preconditioners
# ==================================================================================

[Preconditioning]
  [SMP_full]
    type = SMP
    full = true
    petsc_options = '-snes_ksp_ew -snes_converged_reason'
    petsc_options_iname = '-pc_type -pc_hypre_type -ksp_gmres_restart -pc_hypre_boomeramg_max_iter -pc_hypre_boomeramg_tol'
    petsc_options_value = 'hypre boomeramg 101 20 1.0e-6'
    solve_type = 'PJFNK'
  []
[]

# ==================================================================================
# Executioner and Outputs
# ==================================================================================

[Executioner]
  type = Eigenvalue
  free_power_iterations = 4
  l_max_its = 100
  l_tol = 1e-4
  nl_abs_tol = 1e-8
  nl_max_its = 200
  nl_rel_tol = 1e-7
[]
[Outputs]
  csv = true
  file_base = out~init_refcube
  interval = 1
  [console]
    type = Console
    output_linear = true
    output_nonlinear = true
  []
  [exodus]
    type = Exodus
  []
[]
