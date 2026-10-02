/* ============================================================================
   Hospital Operations Database Platform
   Fase 5 - Implementacion fisica (SQL Server 2016+)

   Contenido: base de datos, esquemas, tablas, PK, FK, UNIQUE, CHECK, DEFAULT.
   No incluye: INSERT, procedimientos, triggers ni indices (Fase 6).

   CONVENCIONES DE NOMBRES
     Esquemas : minuscula por dominio (pac, med, turnos, clin, est, intern, cob, fact, seg)
     Tablas   : PascalCase con guion bajo, singular (Medico_Especialidad)
     PK       : PK_<Tabla>
     FK       : FK_<TablaHija>_<TablaPadre>[_<Rol>]
     UNIQUE   : UQ_<Tabla>_<Columnas>
     CHECK    : CK_<Tabla>_<Regla>
     DEFAULT  : DF_<Tabla>_<Columna>
   ============================================================================ */

USE master;
GO

IF DB_ID(N'HospitalOperationsDB') IS NULL
    CREATE DATABASE HospitalOperationsDB;
GO

USE HospitalOperationsDB;
GO

/* ============================ ESQUEMAS ==================================== */

CREATE SCHEMA pac    AUTHORIZATION dbo;  -- Pacientes
GO
CREATE SCHEMA med    AUTHORIZATION dbo;  -- Gestion medica
GO
CREATE SCHEMA turnos AUTHORIZATION dbo;  -- Agenda y turnos
GO
CREATE SCHEMA clin   AUTHORIZATION dbo;  -- Atencion clinica
GO
CREATE SCHEMA est    AUTHORIZATION dbo;  -- Estudios complementarios
GO
CREATE SCHEMA intern AUTHORIZATION dbo;  -- Internacion
GO
CREATE SCHEMA cob    AUTHORIZATION dbo;  -- Cobertura
GO
CREATE SCHEMA fact   AUTHORIZATION dbo;  -- Facturacion
GO
CREATE SCHEMA seg    AUTHORIZATION dbo;  -- Seguridad y auditoria
GO

/* ============================ SEGURIDAD (base) ============================ */

CREATE TABLE seg.Rol (
    Id_Rol       INT IDENTITY(1,1) NOT NULL,
    Nombre       NVARCHAR(50)      NOT NULL,
    Descripcion  NVARCHAR(200)     NULL,
    Estado       VARCHAR(10)       NOT NULL CONSTRAINT DF_Rol_Estado DEFAULT 'activo',
    CONSTRAINT PK_Rol        PRIMARY KEY (Id_Rol),
    CONSTRAINT UQ_Rol_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_Rol_Estado CHECK (Estado IN ('activo','inactivo'))
);
GO

/* ============================ PACIENTES =================================== */

CREATE TABLE pac.Paciente (
    Id_Paciente         INT IDENTITY(1,1) NOT NULL,
    Tipo_Documento      VARCHAR(10)       NOT NULL,
    Numero_Documento    VARCHAR(20)       NOT NULL,
    Apellidos           NVARCHAR(100)     NOT NULL,
    Nombres             NVARCHAR(100)     NOT NULL,
    Fecha_Nacimiento    DATE              NOT NULL,
    Sexo                CHAR(1)           NULL,
    Estado              VARCHAR(12)       NOT NULL CONSTRAINT DF_Paciente_Estado DEFAULT 'activo',
    Fecha_Alta          DATE              NOT NULL CONSTRAINT DF_Paciente_Fecha_Alta DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Fecha_Fallecimiento DATE              NULL,
    CONSTRAINT PK_Paciente           PRIMARY KEY (Id_Paciente),
    CONSTRAINT UQ_Paciente_Documento UNIQUE (Tipo_Documento, Numero_Documento),
    CONSTRAINT CK_Paciente_Estado    CHECK (Estado IN ('activo','inactivo','fallecido')),
    CONSTRAINT CK_Paciente_Sexo      CHECK (Sexo IS NULL OR Sexo IN ('F','M','X')),
    CONSTRAINT CK_Paciente_Nacimiento CHECK (Fecha_Nacimiento <= CAST(SYSDATETIME() AS DATE)),
    CONSTRAINT CK_Paciente_Fallecimiento CHECK (
        Fecha_Fallecimiento IS NULL
        OR (Estado = 'fallecido' AND Fecha_Fallecimiento >= Fecha_Nacimiento)
    ),
    CONSTRAINT CK_Paciente_Fallecido_Fecha CHECK (Estado <> 'fallecido' OR Fecha_Fallecimiento IS NOT NULL)
);
GO

CREATE TABLE pac.Domicilio (
    Id_Domicilio    INT IDENTITY(1,1) NOT NULL,
    Id_Paciente     INT               NOT NULL,
    Tipo            VARCHAR(10)       NOT NULL,
    Calle           NVARCHAR(150)     NOT NULL,
    Numero          VARCHAR(10)       NULL,
    Piso_Depto      VARCHAR(15)       NULL,
    Localidad       NVARCHAR(100)     NOT NULL,
    Provincia       NVARCHAR(100)     NOT NULL,
    Codigo_Postal   VARCHAR(10)       NULL,
    Vigencia_Desde  DATE              NOT NULL,
    Vigencia_Hasta  DATE              NULL,
    CONSTRAINT PK_Domicilio          PRIMARY KEY (Id_Domicilio),
    CONSTRAINT FK_Domicilio_Paciente FOREIGN KEY (Id_Paciente) REFERENCES pac.Paciente (Id_Paciente),
    CONSTRAINT UQ_Domicilio_Paciente_Tipo_Desde UNIQUE (Id_Paciente, Tipo, Vigencia_Desde),
    CONSTRAINT CK_Domicilio_Tipo     CHECK (Tipo IN ('real','legal')),
    CONSTRAINT CK_Domicilio_Vigencia CHECK (Vigencia_Hasta IS NULL OR Vigencia_Hasta >= Vigencia_Desde)
);
GO

CREATE TABLE pac.Contacto_Paciente (
    Id_Contacto     INT IDENTITY(1,1) NOT NULL,
    Id_Paciente     INT               NOT NULL,
    Tipo            VARCHAR(20)       NOT NULL,
    Valor           NVARCHAR(150)     NOT NULL,
    Nombre_Contacto NVARCHAR(150)     NULL,
    Es_Principal    BIT               NOT NULL CONSTRAINT DF_Contacto_Es_Principal DEFAULT 0,
    Estado          VARCHAR(10)       NOT NULL CONSTRAINT DF_Contacto_Estado DEFAULT 'activo',
    CONSTRAINT PK_Contacto_Paciente          PRIMARY KEY (Id_Contacto),
    CONSTRAINT FK_Contacto_Paciente_Paciente FOREIGN KEY (Id_Paciente) REFERENCES pac.Paciente (Id_Paciente),
    CONSTRAINT UQ_Contacto_Paciente_Valor    UNIQUE (Id_Paciente, Tipo, Valor),
    CONSTRAINT CK_Contacto_Tipo   CHECK (Tipo IN ('telefono','celular','email','familiar_responsable')),
    CONSTRAINT CK_Contacto_Estado CHECK (Estado IN ('activo','inactivo')),
    CONSTRAINT CK_Contacto_Email  CHECK (Tipo <> 'email' OR Valor LIKE '%_@_%._%'),
    CONSTRAINT CK_Contacto_Familiar_Nombre CHECK (Tipo <> 'familiar_responsable' OR Nombre_Contacto IS NOT NULL)
);
GO

/* ============================ GESTION MEDICA ============================== */

CREATE TABLE med.Especialidad (
    Id_Especialidad INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(100)     NOT NULL,
    Descripcion     NVARCHAR(300)     NULL,
    Estado          VARCHAR(10)       NOT NULL CONSTRAINT DF_Especialidad_Estado DEFAULT 'activo',
    CONSTRAINT PK_Especialidad        PRIMARY KEY (Id_Especialidad),
    CONSTRAINT UQ_Especialidad_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_Especialidad_Estado CHECK (Estado IN ('activo','inactivo'))
);
GO

CREATE TABLE med.Medico (
    Id_Medico        INT IDENTITY(1,1) NOT NULL,
    Matricula        VARCHAR(20)       NOT NULL,
    Tipo_Documento   VARCHAR(10)       NOT NULL,
    Numero_Documento VARCHAR(20)       NOT NULL,
    Apellidos        NVARCHAR(100)     NOT NULL,
    Nombres          NVARCHAR(100)     NOT NULL,
    Fecha_Ingreso    DATE              NOT NULL,
    Fecha_Baja       DATE              NULL,
    Estado           VARCHAR(10)       NOT NULL CONSTRAINT DF_Medico_Estado DEFAULT 'activo',
    CONSTRAINT PK_Medico           PRIMARY KEY (Id_Medico),
    CONSTRAINT UQ_Medico_Matricula UNIQUE (Matricula),
    CONSTRAINT UQ_Medico_Documento UNIQUE (Tipo_Documento, Numero_Documento),
    CONSTRAINT CK_Medico_Estado    CHECK (Estado IN ('activo','inactivo','baja')),
    CONSTRAINT CK_Medico_Baja      CHECK (Fecha_Baja IS NULL OR Fecha_Baja >= Fecha_Ingreso),
    CONSTRAINT CK_Medico_Baja_Estado CHECK (Estado <> 'baja' OR Fecha_Baja IS NOT NULL)
);
GO

CREATE TABLE med.Medico_Especialidad (
    Id_MedicoEspecialidad  INT IDENTITY(1,1) NOT NULL,
    Id_Medico              INT               NOT NULL,
    Id_Especialidad        INT               NOT NULL,
    Matricula_Especialidad VARCHAR(20)       NULL,
    Fecha_Habilitacion     DATE              NULL,
    Vigencia_Desde         DATE              NOT NULL,
    Vigencia_Hasta         DATE              NULL,
    Es_Principal           BIT               NOT NULL CONSTRAINT DF_MedEsp_Es_Principal DEFAULT 0,
    CONSTRAINT PK_Medico_Especialidad PRIMARY KEY (Id_MedicoEspecialidad),
    CONSTRAINT FK_MedicoEspecialidad_Medico       FOREIGN KEY (Id_Medico)       REFERENCES med.Medico (Id_Medico),
    CONSTRAINT FK_MedicoEspecialidad_Especialidad FOREIGN KEY (Id_Especialidad) REFERENCES med.Especialidad (Id_Especialidad),
    CONSTRAINT UQ_MedicoEspecialidad_Vigencia UNIQUE (Id_Medico, Id_Especialidad, Vigencia_Desde),
    CONSTRAINT CK_MedicoEspecialidad_Vigencia CHECK (Vigencia_Hasta IS NULL OR Vigencia_Hasta >= Vigencia_Desde)
);
GO

/* ============================ SEGURIDAD (usuarios) ======================== */
-- Se crea aqui porque Turno y Pago referencian a Usuario_Sistema.

CREATE TABLE seg.Usuario_Sistema (
    Id_Usuario      INT IDENTITY(1,1) NOT NULL,
    Id_Rol          INT               NOT NULL,
    Id_Medico       INT               NULL,
    Nombre_Usuario  NVARCHAR(100)     NOT NULL,
    Apellido_Nombre NVARCHAR(200)     NULL,
    Estado          VARCHAR(10)       NOT NULL CONSTRAINT DF_Usuario_Estado DEFAULT 'activo',
    Fecha_Alta      DATE              NOT NULL CONSTRAINT DF_Usuario_Fecha_Alta DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Ultimo_Acceso   DATETIME2(0)      NULL,
    CONSTRAINT PK_Usuario_Sistema PRIMARY KEY (Id_Usuario),
    CONSTRAINT FK_Usuario_Rol     FOREIGN KEY (Id_Rol)    REFERENCES seg.Rol (Id_Rol),
    CONSTRAINT FK_Usuario_Medico  FOREIGN KEY (Id_Medico) REFERENCES med.Medico (Id_Medico),
    CONSTRAINT UQ_Usuario_Nombre  UNIQUE (Nombre_Usuario),
    CONSTRAINT CK_Usuario_Estado  CHECK (Estado IN ('activo','inactivo','bloqueado'))
);
GO

/* ============================ TURNOS ====================================== */

CREATE TABLE turnos.Agenda (
    Id_Agenda          INT IDENTITY(1,1) NOT NULL,
    Id_Medico          INT               NOT NULL,
    Id_Especialidad    INT               NOT NULL,
    Dia_Semana         TINYINT           NOT NULL,
    Hora_Inicio        TIME(0)           NOT NULL,
    Hora_Fin           TIME(0)           NOT NULL,
    Duracion_Turno_Min SMALLINT          NOT NULL,
    Vigencia_Desde     DATE              NOT NULL,
    Vigencia_Hasta     DATE              NULL,
    Consultorio        NVARCHAR(30)      NULL,
    Estado             VARCHAR(10)       NOT NULL CONSTRAINT DF_Agenda_Estado DEFAULT 'activa',
    CONSTRAINT PK_Agenda PRIMARY KEY (Id_Agenda),
    CONSTRAINT FK_Agenda_Medico       FOREIGN KEY (Id_Medico)       REFERENCES med.Medico (Id_Medico),
    CONSTRAINT FK_Agenda_Especialidad FOREIGN KEY (Id_Especialidad) REFERENCES med.Especialidad (Id_Especialidad),
    CONSTRAINT CK_Agenda_Dia       CHECK (Dia_Semana BETWEEN 1 AND 7),
    CONSTRAINT CK_Agenda_Horario   CHECK (Hora_Fin > Hora_Inicio),
    CONSTRAINT CK_Agenda_Duracion  CHECK (Duracion_Turno_Min > 0),
    CONSTRAINT CK_Agenda_Vigencia  CHECK (Vigencia_Hasta IS NULL OR Vigencia_Hasta >= Vigencia_Desde),
    CONSTRAINT CK_Agenda_Estado    CHECK (Estado IN ('activa','inactiva'))
);
GO

CREATE TABLE turnos.Turno (
    Id_Turno           INT IDENTITY(1,1) NOT NULL,
    Id_Agenda          INT               NOT NULL,
    Id_Paciente        INT               NOT NULL,
    Id_Usuario         INT               NOT NULL,
    Fecha_Hora         DATETIME2(0)      NOT NULL,
    Estado             VARCHAR(12)       NOT NULL CONSTRAINT DF_Turno_Estado DEFAULT 'reservado',
    Fecha_Reserva      DATETIME2(0)      NOT NULL CONSTRAINT DF_Turno_Fecha_Reserva DEFAULT (SYSDATETIME()),
    Motivo_Cancelacion NVARCHAR(200)     NULL,
    Fecha_Cancelacion  DATETIME2(0)      NULL,
    Observaciones      NVARCHAR(500)     NULL,
    CONSTRAINT PK_Turno PRIMARY KEY (Id_Turno),
    CONSTRAINT FK_Turno_Agenda   FOREIGN KEY (Id_Agenda)   REFERENCES turnos.Agenda (Id_Agenda),
    CONSTRAINT FK_Turno_Paciente FOREIGN KEY (Id_Paciente) REFERENCES pac.Paciente (Id_Paciente),
    CONSTRAINT FK_Turno_Usuario  FOREIGN KEY (Id_Usuario)  REFERENCES seg.Usuario_Sistema (Id_Usuario),
    CONSTRAINT CK_Turno_Estado   CHECK (Estado IN ('reservado','confirmado','atendido','ausente','cancelado')),
    CONSTRAINT CK_Turno_Cancelacion CHECK (
        (Estado = 'cancelado' AND Motivo_Cancelacion IS NOT NULL AND Fecha_Cancelacion IS NOT NULL)
        OR (Estado <> 'cancelado' AND Motivo_Cancelacion IS NULL AND Fecha_Cancelacion IS NULL)
    )
);
GO

/* ============================ ATENCION CLINICA ============================ */

CREATE TABLE clin.Diagnostico (
    Id_Diagnostico INT IDENTITY(1,1) NOT NULL,
    Codigo         VARCHAR(10)       NOT NULL,   -- CIE-10
    Descripcion    NVARCHAR(300)     NOT NULL,
    Estado         VARCHAR(10)       NOT NULL CONSTRAINT DF_Diagnostico_Estado DEFAULT 'activo',
    CONSTRAINT PK_Diagnostico        PRIMARY KEY (Id_Diagnostico),
    CONSTRAINT UQ_Diagnostico_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_Diagnostico_Estado CHECK (Estado IN ('activo','inactivo'))
);
GO

CREATE TABLE clin.Atencion (
    Id_Atencion     INT IDENTITY(1,1) NOT NULL,
    Id_Paciente     INT               NOT NULL,
    Id_Medico       INT               NOT NULL,
    Id_Especialidad INT               NOT NULL,
    Id_Turno        INT               NULL,
    Id_Diagnostico  INT               NULL,
    Fecha_Hora      DATETIME2(0)      NOT NULL,
    Tipo            VARCHAR(15)       NOT NULL,
    Motivo_Consulta NVARCHAR(500)     NOT NULL,
    Indicaciones    NVARCHAR(1000)    NULL,
    Estado          VARCHAR(10)       NOT NULL CONSTRAINT DF_Atencion_Estado DEFAULT 'registrada',
    CONSTRAINT PK_Atencion PRIMARY KEY (Id_Atencion),
    CONSTRAINT FK_Atencion_Paciente     FOREIGN KEY (Id_Paciente)     REFERENCES pac.Paciente (Id_Paciente),
    CONSTRAINT FK_Atencion_Medico       FOREIGN KEY (Id_Medico)       REFERENCES med.Medico (Id_Medico),
    CONSTRAINT FK_Atencion_Especialidad FOREIGN KEY (Id_Especialidad) REFERENCES med.Especialidad (Id_Especialidad),
    CONSTRAINT FK_Atencion_Turno        FOREIGN KEY (Id_Turno)        REFERENCES turnos.Turno (Id_Turno),
    CONSTRAINT FK_Atencion_Diagnostico  FOREIGN KEY (Id_Diagnostico)  REFERENCES clin.Diagnostico (Id_Diagnostico),
    CONSTRAINT CK_Atencion_Tipo   CHECK (Tipo IN ('ambulatoria','guardia','internacion')),
    CONSTRAINT CK_Atencion_Estado CHECK (Estado IN ('registrada','anulada')),
    CONSTRAINT CK_Atencion_Ambulatoria_Turno CHECK (Tipo <> 'ambulatoria' OR Id_Turno IS NOT NULL)
);
GO

/* ============================ ESTUDIOS ==================================== */

CREATE TABLE est.Tipo_Estudio (
    Id_TipoEstudio          INT IDENTITY(1,1) NOT NULL,
    Codigo                  VARCHAR(20)       NOT NULL,
    Nombre                  NVARCHAR(150)     NOT NULL,
    Categoria               VARCHAR(15)       NOT NULL,
    Requiere_Preparacion    BIT               NOT NULL CONSTRAINT DF_TipoEstudio_Prep DEFAULT 0,
    Indicaciones_Preparacion NVARCHAR(500)    NULL,
    Estado                  VARCHAR(10)       NOT NULL CONSTRAINT DF_TipoEstudio_Estado DEFAULT 'activo',
    CONSTRAINT PK_Tipo_Estudio        PRIMARY KEY (Id_TipoEstudio),
    CONSTRAINT UQ_TipoEstudio_Codigo  UNIQUE (Codigo),
    CONSTRAINT CK_TipoEstudio_Categoria CHECK (Categoria IN ('laboratorio','imagenes','otros')),
    CONSTRAINT CK_TipoEstudio_Estado    CHECK (Estado IN ('activo','inactivo'))
);
GO

CREATE TABLE est.Solicitud_Estudio (
    Id_Solicitud      INT IDENTITY(1,1) NOT NULL,
    Id_Atencion       INT               NOT NULL,
    Id_TipoEstudio    INT               NOT NULL,
    Fecha_Solicitud   DATETIME2(0)      NOT NULL CONSTRAINT DF_Solicitud_Fecha DEFAULT (SYSDATETIME()),
    Prioridad         VARCHAR(10)       NOT NULL CONSTRAINT DF_Solicitud_Prioridad DEFAULT 'normal',
    Indicacion_Clinica NVARCHAR(500)    NULL,
    Estado            VARCHAR(12)       NOT NULL CONSTRAINT DF_Solicitud_Estado DEFAULT 'solicitado',
    Motivo_Anulacion  NVARCHAR(200)     NULL,
    CONSTRAINT PK_Solicitud_Estudio PRIMARY KEY (Id_Solicitud),
    CONSTRAINT FK_Solicitud_Atencion    FOREIGN KEY (Id_Atencion)    REFERENCES clin.Atencion (Id_Atencion),
    CONSTRAINT FK_Solicitud_TipoEstudio FOREIGN KEY (Id_TipoEstudio) REFERENCES est.Tipo_Estudio (Id_TipoEstudio),
    CONSTRAINT CK_Solicitud_Prioridad CHECK (Prioridad IN ('normal','urgente')),
    CONSTRAINT CK_Solicitud_Estado    CHECK (Estado IN ('solicitado','realizado','informado','anulado')),
    CONSTRAINT CK_Solicitud_Anulacion CHECK (
        (Estado = 'anulado' AND Motivo_Anulacion IS NOT NULL)
        OR (Estado <> 'anulado' AND Motivo_Anulacion IS NULL)
    )
);
GO

CREATE TABLE est.Resultado_Estudio (
    Id_Resultado      INT IDENTITY(1,1) NOT NULL,
    Id_Solicitud      INT               NOT NULL,
    Id_Medico         INT               NULL,
    Fecha_Realizacion DATETIME2(0)      NOT NULL,
    Fecha_Informe     DATETIME2(0)      NULL,
    Resultado_Resumido NVARCHAR(2000)   NULL,
    Estado_Validacion VARCHAR(12)       NOT NULL CONSTRAINT DF_Resultado_Validacion DEFAULT 'pendiente',
    CONSTRAINT PK_Resultado_Estudio PRIMARY KEY (Id_Resultado),
    CONSTRAINT FK_Resultado_Solicitud FOREIGN KEY (Id_Solicitud) REFERENCES est.Solicitud_Estudio (Id_Solicitud),
    CONSTRAINT FK_Resultado_Medico    FOREIGN KEY (Id_Medico)    REFERENCES med.Medico (Id_Medico),
    CONSTRAINT UQ_Resultado_Solicitud UNIQUE (Id_Solicitud),
    CONSTRAINT CK_Resultado_Informe    CHECK (Fecha_Informe IS NULL OR Fecha_Informe >= Fecha_Realizacion),
    CONSTRAINT CK_Resultado_Validacion CHECK (Estado_Validacion IN ('pendiente','validado','rectificado'))
);
GO

/* ============================ INTERNACION ================================= */

CREATE TABLE intern.Sector (
    Id_Sector INT IDENTITY(1,1) NOT NULL,
    Nombre    NVARCHAR(100)     NOT NULL,
    Tipo      VARCHAR(30)       NOT NULL,
    Capacidad SMALLINT          NOT NULL,
    Estado    VARCHAR(10)       NOT NULL CONSTRAINT DF_Sector_Estado DEFAULT 'activo',
    CONSTRAINT PK_Sector        PRIMARY KEY (Id_Sector),
    CONSTRAINT UQ_Sector_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_Sector_Capacidad CHECK (Capacidad > 0),
    CONSTRAINT CK_Sector_Estado    CHECK (Estado IN ('activo','inactivo'))
);
GO

CREATE TABLE intern.Cama (
    Id_Cama       INT IDENTITY(1,1) NOT NULL,
    Id_Sector     INT               NOT NULL,
    Identificador VARCHAR(20)       NOT NULL,
    Estado        VARCHAR(15)       NOT NULL CONSTRAINT DF_Cama_Estado DEFAULT 'disponible',
    CONSTRAINT PK_Cama PRIMARY KEY (Id_Cama),
    CONSTRAINT FK_Cama_Sector FOREIGN KEY (Id_Sector) REFERENCES intern.Sector (Id_Sector),
    CONSTRAINT UQ_Cama_Sector_Identificador UNIQUE (Id_Sector, Identificador),
    CONSTRAINT CK_Cama_Estado CHECK (Estado IN ('disponible','ocupada','mantenimiento'))
);
GO

CREATE TABLE intern.Internacion (
    Id_Internacion     INT IDENTITY(1,1) NOT NULL,
    Id_Paciente        INT               NOT NULL,
    Id_Medico          INT               NOT NULL,
    Id_Diagnostico     INT               NULL,
    Fecha_Hora_Ingreso DATETIME2(0)      NOT NULL,
    Fecha_Hora_Egreso  DATETIME2(0)      NULL,
    Motivo             NVARCHAR(500)     NOT NULL,
    Tipo_Egreso        VARCHAR(15)       NULL,
    Estado             VARCHAR(12)       NOT NULL CONSTRAINT DF_Internacion_Estado DEFAULT 'activa',
    CONSTRAINT PK_Internacion PRIMARY KEY (Id_Internacion),
    CONSTRAINT FK_Internacion_Paciente    FOREIGN KEY (Id_Paciente)    REFERENCES pac.Paciente (Id_Paciente),
    CONSTRAINT FK_Internacion_Medico      FOREIGN KEY (Id_Medico)      REFERENCES med.Medico (Id_Medico),
    CONSTRAINT FK_Internacion_Diagnostico FOREIGN KEY (Id_Diagnostico) REFERENCES clin.Diagnostico (Id_Diagnostico),
    CONSTRAINT CK_Internacion_Estado      CHECK (Estado IN ('activa','finalizada')),
    CONSTRAINT CK_Internacion_Tipo_Egreso CHECK (Tipo_Egreso IS NULL OR Tipo_Egreso IN ('alta','traslado','derivacion','obito')),
    CONSTRAINT CK_Internacion_Egreso_Fecha CHECK (Fecha_Hora_Egreso IS NULL OR Fecha_Hora_Egreso > Fecha_Hora_Ingreso),
    CONSTRAINT CK_Internacion_Cierre CHECK (
        (Estado = 'finalizada' AND Fecha_Hora_Egreso IS NOT NULL AND Tipo_Egreso IS NOT NULL)
        OR (Estado = 'activa'  AND Fecha_Hora_Egreso IS NULL     AND Tipo_Egreso IS NULL)
    )
);
GO

CREATE TABLE intern.Asignacion_Cama (
    Id_Asignacion    INT IDENTITY(1,1) NOT NULL,
    Id_Internacion   INT               NOT NULL,
    Id_Cama          INT               NOT NULL,
    Fecha_Hora_Desde DATETIME2(0)      NOT NULL,
    Fecha_Hora_Hasta DATETIME2(0)      NULL,
    CONSTRAINT PK_Asignacion_Cama PRIMARY KEY (Id_Asignacion),
    CONSTRAINT FK_AsignacionCama_Internacion FOREIGN KEY (Id_Internacion) REFERENCES intern.Internacion (Id_Internacion),
    CONSTRAINT FK_AsignacionCama_Cama        FOREIGN KEY (Id_Cama)        REFERENCES intern.Cama (Id_Cama),
    CONSTRAINT UQ_AsignacionCama_Cama_Desde  UNIQUE (Id_Cama, Fecha_Hora_Desde),
    CONSTRAINT CK_AsignacionCama_Periodo CHECK (Fecha_Hora_Hasta IS NULL OR Fecha_Hora_Hasta > Fecha_Hora_Desde)
);
GO

/* ============================ COBERTURA =================================== */

CREATE TABLE cob.Obra_Social (
    Id_ObraSocial          INT IDENTITY(1,1) NOT NULL,
    Razon_Social           NVARCHAR(200)     NOT NULL,
    Codigo                 VARCHAR(20)       NOT NULL,
    CUIT                   CHAR(11)          NOT NULL,
    Tipo                   VARCHAR(15)       NOT NULL,
    Direccion_Presentacion NVARCHAR(250)     NULL,
    Estado_Convenio        VARCHAR(12)       NOT NULL CONSTRAINT DF_ObraSocial_Convenio DEFAULT 'vigente',
    Vigencia_Convenio      DATE              NULL,
    CONSTRAINT PK_Obra_Social        PRIMARY KEY (Id_ObraSocial),
    CONSTRAINT UQ_ObraSocial_Codigo  UNIQUE (Codigo),
    CONSTRAINT UQ_ObraSocial_CUIT    UNIQUE (CUIT),
    CONSTRAINT CK_ObraSocial_Tipo    CHECK (Tipo IN ('obra_social','prepaga')),
    CONSTRAINT CK_ObraSocial_Convenio CHECK (Estado_Convenio IN ('vigente','suspendido','vencido','sin_convenio')),
    CONSTRAINT CK_ObraSocial_CUIT    CHECK (CUIT NOT LIKE '%[^0-9]%')
);
GO

CREATE TABLE cob.[Plan] (
    Id_Plan         INT IDENTITY(1,1) NOT NULL,
    Id_ObraSocial   INT               NOT NULL,
    Nombre          NVARCHAR(100)     NOT NULL,
    Nivel_Cobertura NVARCHAR(50)      NULL,
    Vigencia_Desde  DATE              NOT NULL,
    Vigencia_Hasta  DATE              NULL,
    Estado          VARCHAR(10)       NOT NULL CONSTRAINT DF_Plan_Estado DEFAULT 'activo',
    CONSTRAINT PK_Plan PRIMARY KEY (Id_Plan),
    CONSTRAINT FK_Plan_ObraSocial FOREIGN KEY (Id_ObraSocial) REFERENCES cob.Obra_Social (Id_ObraSocial),
    CONSTRAINT UQ_Plan_ObraSocial_Nombre UNIQUE (Id_ObraSocial, Nombre),
    CONSTRAINT CK_Plan_Vigencia CHECK (Vigencia_Hasta IS NULL OR Vigencia_Hasta >= Vigencia_Desde),
    CONSTRAINT CK_Plan_Estado   CHECK (Estado IN ('activo','inactivo'))
);
GO

CREATE TABLE cob.Afiliacion (
    Id_Afiliacion   INT IDENTITY(1,1) NOT NULL,
    Id_Paciente     INT               NOT NULL,
    Id_Plan         INT               NOT NULL,
    Numero_Afiliado VARCHAR(30)       NOT NULL,
    Condicion       VARCHAR(10)       NOT NULL,
    Vigencia_Desde  DATE              NOT NULL,
    Vigencia_Hasta  DATE              NULL,
    Estado          VARCHAR(10)       NOT NULL CONSTRAINT DF_Afiliacion_Estado DEFAULT 'vigente',
    CONSTRAINT PK_Afiliacion PRIMARY KEY (Id_Afiliacion),
    CONSTRAINT FK_Afiliacion_Paciente FOREIGN KEY (Id_Paciente) REFERENCES pac.Paciente (Id_Paciente),
    CONSTRAINT FK_Afiliacion_Plan     FOREIGN KEY (Id_Plan)     REFERENCES cob.[Plan] (Id_Plan),
    CONSTRAINT UQ_Afiliacion_Plan_Numero_Desde UNIQUE (Id_Plan, Numero_Afiliado, Vigencia_Desde),
    CONSTRAINT CK_Afiliacion_Condicion CHECK (Condicion IN ('titular','adherente')),
    CONSTRAINT CK_Afiliacion_Vigencia  CHECK (Vigencia_Hasta IS NULL OR Vigencia_Hasta >= Vigencia_Desde),
    CONSTRAINT CK_Afiliacion_Estado    CHECK (Estado IN ('vigente','suspendida','baja'))
);
GO

/* ============================ FACTURACION ================================= */

CREATE TABLE fact.Nomenclador (
    Id_Nomenclador   INT IDENTITY(1,1) NOT NULL,
    Codigo           VARCHAR(20)       NOT NULL,
    Descripcion      NVARCHAR(300)     NOT NULL,
    Categoria        VARCHAR(30)       NOT NULL,
    Valor_Referencia DECIMAL(18,2)     NOT NULL,
    Vigencia_Desde   DATE              NOT NULL,
    Vigencia_Hasta   DATE              NULL,
    CONSTRAINT PK_Nomenclador PRIMARY KEY (Id_Nomenclador),
    CONSTRAINT UQ_Nomenclador_Codigo_Desde UNIQUE (Codigo, Vigencia_Desde),
    CONSTRAINT CK_Nomenclador_Valor    CHECK (Valor_Referencia >= 0),
    CONSTRAINT CK_Nomenclador_Vigencia CHECK (Vigencia_Hasta IS NULL OR Vigencia_Hasta >= Vigencia_Desde)
);
GO

CREATE TABLE fact.Liquidacion (
    Id_Liquidacion      INT IDENTITY(1,1) NOT NULL,
    Id_ObraSocial       INT               NOT NULL,
    Periodo             CHAR(6)           NOT NULL,   -- AAAAMM
    Numero_Presentacion INT               NOT NULL CONSTRAINT DF_Liquidacion_Presentacion DEFAULT 1,
    Fecha_Emision       DATE              NULL,
    Importe_Total       DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Liquidacion_Importe DEFAULT 0,
    Estado              VARCHAR(10)       NOT NULL CONSTRAINT DF_Liquidacion_Estado DEFAULT 'borrador',
    CONSTRAINT PK_Liquidacion PRIMARY KEY (Id_Liquidacion),
    CONSTRAINT FK_Liquidacion_ObraSocial FOREIGN KEY (Id_ObraSocial) REFERENCES cob.Obra_Social (Id_ObraSocial),
    CONSTRAINT UQ_Liquidacion_OS_Periodo_Presentacion UNIQUE (Id_ObraSocial, Periodo, Numero_Presentacion),
    CONSTRAINT CK_Liquidacion_Importe      CHECK (Importe_Total >= 0),
    CONSTRAINT CK_Liquidacion_Presentacion CHECK (Numero_Presentacion > 0),
    CONSTRAINT CK_Liquidacion_Periodo      CHECK (Periodo LIKE '[0-9][0-9][0-9][0-9][0-1][0-9]' AND RIGHT(Periodo,2) BETWEEN '01' AND '12'),
    CONSTRAINT CK_Liquidacion_Estado       CHECK (Estado IN ('borrador','presentada','observada','cerrada'))
);
GO

CREATE TABLE fact.Prestacion (
    Id_Prestacion      INT IDENTITY(1,1) NOT NULL,
    Id_Nomenclador     INT               NOT NULL,
    Id_Afiliacion      INT               NULL,
    Id_Liquidacion     INT               NULL,
    Id_Atencion        INT               NULL,
    Id_Solicitud       INT               NULL,
    Id_Internacion     INT               NULL,
    Fecha_Realizacion  DATE              NOT NULL,
    Cantidad           INT               NOT NULL CONSTRAINT DF_Prestacion_Cantidad DEFAULT 1,
    Valor_Aplicado     DECIMAL(18,2)     NOT NULL,
    Porcentaje_Cubierto DECIMAL(5,2)     NOT NULL,
    Estado             VARCHAR(10)       NOT NULL CONSTRAINT DF_Prestacion_Estado DEFAULT 'pendiente',
    Motivo_Rechazo     NVARCHAR(300)     NULL,
    CONSTRAINT PK_Prestacion PRIMARY KEY (Id_Prestacion),
    CONSTRAINT FK_Prestacion_Nomenclador FOREIGN KEY (Id_Nomenclador) REFERENCES fact.Nomenclador (Id_Nomenclador),
    CONSTRAINT FK_Prestacion_Afiliacion  FOREIGN KEY (Id_Afiliacion)  REFERENCES cob.Afiliacion (Id_Afiliacion),
    CONSTRAINT FK_Prestacion_Liquidacion FOREIGN KEY (Id_Liquidacion) REFERENCES fact.Liquidacion (Id_Liquidacion),
    CONSTRAINT FK_Prestacion_Atencion    FOREIGN KEY (Id_Atencion)    REFERENCES clin.Atencion (Id_Atencion),
    CONSTRAINT FK_Prestacion_Solicitud   FOREIGN KEY (Id_Solicitud)   REFERENCES est.Solicitud_Estudio (Id_Solicitud),
    CONSTRAINT FK_Prestacion_Internacion FOREIGN KEY (Id_Internacion) REFERENCES intern.Internacion (Id_Internacion),
    CONSTRAINT CK_Prestacion_Origen_Unico CHECK (
        (CASE WHEN Id_Atencion   IS NULL THEN 0 ELSE 1 END
       + CASE WHEN Id_Solicitud  IS NULL THEN 0 ELSE 1 END
       + CASE WHEN Id_Internacion IS NULL THEN 0 ELSE 1 END) = 1
    ),
    CONSTRAINT CK_Prestacion_Cantidad   CHECK (Cantidad > 0),
    CONSTRAINT CK_Prestacion_Valor      CHECK (Valor_Aplicado >= 0),
    CONSTRAINT CK_Prestacion_Porcentaje CHECK (Porcentaje_Cubierto BETWEEN 0 AND 100),
    CONSTRAINT CK_Prestacion_Estado     CHECK (Estado IN ('pendiente','liquidada','rechazada','cobrada')),
    CONSTRAINT CK_Prestacion_Rechazo    CHECK (
        (Estado = 'rechazada' AND Motivo_Rechazo IS NOT NULL)
        OR (Estado <> 'rechazada')
    ),
    CONSTRAINT CK_Prestacion_Liquidada  CHECK (Estado = 'pendiente' OR Id_Liquidacion IS NOT NULL OR Estado = 'rechazada')
);
GO

CREATE TABLE fact.Pago (
    Id_Pago             INT IDENTITY(1,1) NOT NULL,
    Id_Liquidacion      INT               NOT NULL,
    Id_Usuario          INT               NOT NULL,
    Fecha               DATE              NOT NULL CONSTRAINT DF_Pago_Fecha DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Importe             DECIMAL(18,2)     NOT NULL,
    Medio               VARCHAR(20)       NOT NULL,
    Referencia          VARCHAR(50)       NULL,
    Estado_Conciliacion VARCHAR(12)       NOT NULL CONSTRAINT DF_Pago_Conciliacion DEFAULT 'pendiente',
    CONSTRAINT PK_Pago PRIMARY KEY (Id_Pago),
    CONSTRAINT FK_Pago_Liquidacion FOREIGN KEY (Id_Liquidacion) REFERENCES fact.Liquidacion (Id_Liquidacion),
    CONSTRAINT FK_Pago_Usuario     FOREIGN KEY (Id_Usuario)     REFERENCES seg.Usuario_Sistema (Id_Usuario),
    CONSTRAINT CK_Pago_Importe      CHECK (Importe > 0),
    CONSTRAINT CK_Pago_Medio        CHECK (Medio IN ('transferencia','cheque','efectivo','debito_automatico','otro')),
    CONSTRAINT CK_Pago_Conciliacion CHECK (Estado_Conciliacion IN ('pendiente','conciliado','observado'))
);
GO

/* ============================ AUDITORIA =================================== */

CREATE TABLE seg.Registro_Auditoria (
    Id_Auditoria         BIGINT IDENTITY(1,1) NOT NULL,
    Id_Usuario           INT                  NOT NULL,
    Fecha_Hora           DATETIME2(3)         NOT NULL CONSTRAINT DF_Auditoria_Fecha DEFAULT (SYSDATETIME()),
    Entidad_Afectada     NVARCHAR(128)        NOT NULL,
    Id_Registro_Afectado VARCHAR(50)          NOT NULL,  -- referencia logica, sin FK
    Tipo_Operacion       VARCHAR(12)          NOT NULL,
    Valor_Anterior       NVARCHAR(MAX)        NULL,
    Valor_Nuevo          NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_Registro_Auditoria PRIMARY KEY (Id_Auditoria),
    CONSTRAINT FK_Auditoria_Usuario  FOREIGN KEY (Id_Usuario) REFERENCES seg.Usuario_Sistema (Id_Usuario),
    CONSTRAINT CK_Auditoria_Operacion CHECK (Tipo_Operacion IN ('alta','modificacion','baja')),
    CONSTRAINT CK_Auditoria_Valores   CHECK (
        (Tipo_Operacion = 'alta'         AND Valor_Nuevo IS NOT NULL)
        OR (Tipo_Operacion = 'baja'      AND Valor_Anterior IS NOT NULL)
        OR (Tipo_Operacion = 'modificacion' AND Valor_Anterior IS NOT NULL AND Valor_Nuevo IS NOT NULL)
    )
);
GO

/* ============================================================================
   PENDIENTE PARA LA FASE 6 (indices): estas reglas de unicidad parcial NO se
   pueden expresar como UNIQUE constraint porque SQL Server admite un solo NULL
   en una columna con UNIQUE, o porque aplican a un subconjunto de filas.
     - Atencion.Id_Turno            (unico cuando no es NULL)
     - Usuario_Sistema.Id_Medico    (unico cuando no es NULL)
     - Pago (Medio, Referencia)     (unico cuando Referencia no es NULL)
     - Turno (Id_Agenda, Fecha_Hora) (unico para estado <> 'cancelado')
     - Contacto_Paciente principal  (uno por paciente y tipo)
     - Internacion activa           (una por paciente)
     - Asignacion_Cama abierta      (una por internacion y una por cama)
     - Domicilio vigente            (uno por paciente y tipo)
   ============================================================================ */
