export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      availability: {
        Row: {
          branch_id: string
          from_time: string
          id: string
          note: string | null
          org_id: string
          to_time: string
          user_id: string
          weekday: number
        }
        Insert: {
          branch_id: string
          from_time: string
          id?: string
          note?: string | null
          org_id: string
          to_time: string
          user_id: string
          weekday: number
        }
        Update: {
          branch_id?: string
          from_time?: string
          id?: string
          note?: string | null
          org_id?: string
          to_time?: string
          user_id?: string
          weekday?: number
        }
        Relationships: [
          {
            foreignKeyName: "availability_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      branch_members: {
        Row: {
          branch_id: string
          created_at: string
          position: string | null
          role: Database["public"]["Enums"]["branch_role"]
          user_id: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          position?: string | null
          role?: Database["public"]["Enums"]["branch_role"]
          user_id: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          position?: string | null
          role?: Database["public"]["Enums"]["branch_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "branch_members_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "branch_members_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      branch_product_settings: {
        Row: {
          branch_id: string
          min_stock: number
          org_id: string
          product_id: string
        }
        Insert: {
          branch_id: string
          min_stock?: number
          org_id: string
          product_id: string
        }
        Update: {
          branch_id?: string
          min_stock?: number
          org_id?: string
          product_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "branch_product_settings_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "branch_product_settings_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "branch_product_settings_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      branches: {
        Row: {
          active: boolean
          address: string | null
          created_at: string
          id: string
          name: string
          org_id: string
          timezone: string
        }
        Insert: {
          active?: boolean
          address?: string | null
          created_at?: string
          id?: string
          name: string
          org_id: string
          timezone?: string
        }
        Update: {
          active?: boolean
          address?: string | null
          created_at?: string
          id?: string
          name?: string
          org_id?: string
          timezone?: string
        }
        Relationships: [
          {
            foreignKeyName: "branches_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_channels: {
        Row: {
          branch_id: string | null
          created_at: string
          id: string
          name: string
          org_id: string
          type: Database["public"]["Enums"]["chat_channel_type"]
        }
        Insert: {
          branch_id?: string | null
          created_at?: string
          id?: string
          name: string
          org_id: string
          type: Database["public"]["Enums"]["chat_channel_type"]
        }
        Update: {
          branch_id?: string | null
          created_at?: string
          id?: string
          name?: string
          org_id?: string
          type?: Database["public"]["Enums"]["chat_channel_type"]
        }
        Relationships: [
          {
            foreignKeyName: "chat_channels_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_channels_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_members: {
        Row: {
          channel_id: string
          created_at: string
          user_id: string
        }
        Insert: {
          channel_id: string
          created_at?: string
          user_id: string
        }
        Update: {
          channel_id?: string
          created_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_members_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "chat_channels"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_messages: {
        Row: {
          attachments: Json
          author_id: string
          body: string
          branch_id: string | null
          channel_id: string
          created_at: string
          id: string
          org_id: string
        }
        Insert: {
          attachments?: Json
          author_id?: string
          body: string
          branch_id?: string | null
          channel_id: string
          created_at?: string
          id?: string
          org_id: string
        }
        Update: {
          attachments?: Json
          author_id?: string
          body?: string
          branch_id?: string | null
          channel_id?: string
          created_at?: string
          id?: string
          org_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_messages_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "chat_channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_reads: {
        Row: {
          channel_id: string
          last_read_at: string
          user_id: string
        }
        Insert: {
          channel_id: string
          last_read_at?: string
          user_id: string
        }
        Update: {
          channel_id?: string
          last_read_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_reads_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "chat_channels"
            referencedColumns: ["id"]
          },
        ]
      }
      checklist_templates: {
        Row: {
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          items: Json
          name: string
          org_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          items?: Json
          name: string
          org_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          items?: Json
          name?: string
          org_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "checklist_templates_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      cost_categories: {
        Row: {
          created_at: string
          id: string
          name: string
          org_id: string
          sort: number
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          org_id: string
          sort?: number
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          org_id?: string
          sort?: number
        }
        Relationships: [
          {
            foreignKeyName: "cost_categories_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      cost_entries: {
        Row: {
          amount: number
          branch_id: string
          category_id: string
          created_at: string
          created_by: string | null
          date: string
          id: string
          note: string | null
          org_id: string
          source: Database["public"]["Enums"]["cost_source"]
        }
        Insert: {
          amount?: number
          branch_id: string
          category_id: string
          created_at?: string
          created_by?: string | null
          date?: string
          id?: string
          note?: string | null
          org_id: string
          source?: Database["public"]["Enums"]["cost_source"]
        }
        Update: {
          amount?: number
          branch_id?: string
          category_id?: string
          created_at?: string
          created_by?: string | null
          date?: string
          id?: string
          note?: string | null
          org_id?: string
          source?: Database["public"]["Enums"]["cost_source"]
        }
        Relationships: [
          {
            foreignKeyName: "cost_entries_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cost_entries_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "cost_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cost_entries_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      day_notes: {
        Row: {
          attachments: Json
          author_id: string
          body: string
          branch_id: string
          created_at: string
          date: string
          id: string
          org_id: string
          severity: Database["public"]["Enums"]["day_note_severity"]
        }
        Insert: {
          attachments?: Json
          author_id?: string
          body: string
          branch_id: string
          created_at?: string
          date?: string
          id?: string
          org_id: string
          severity?: Database["public"]["Enums"]["day_note_severity"]
        }
        Update: {
          attachments?: Json
          author_id?: string
          body?: string
          branch_id?: string
          created_at?: string
          date?: string
          id?: string
          org_id?: string
          severity?: Database["public"]["Enums"]["day_note_severity"]
        }
        Relationships: [
          {
            foreignKeyName: "day_notes_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "day_notes_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      invitations: {
        Row: {
          accepted_at: string | null
          branch_id: string | null
          branch_role: Database["public"]["Enums"]["branch_role"] | null
          created_at: string
          email: string
          expires_at: string
          id: string
          invited_by: string | null
          org_id: string
          org_role: Database["public"]["Enums"]["org_role"]
          token: string
        }
        Insert: {
          accepted_at?: string | null
          branch_id?: string | null
          branch_role?: Database["public"]["Enums"]["branch_role"] | null
          created_at?: string
          email: string
          expires_at?: string
          id?: string
          invited_by?: string | null
          org_id: string
          org_role?: Database["public"]["Enums"]["org_role"]
          token?: string
        }
        Update: {
          accepted_at?: string | null
          branch_id?: string | null
          branch_role?: Database["public"]["Enums"]["branch_role"] | null
          created_at?: string
          email?: string
          expires_at?: string
          id?: string
          invited_by?: string | null
          org_id?: string
          org_role?: Database["public"]["Enums"]["org_role"]
          token?: string
        }
        Relationships: [
          {
            foreignKeyName: "invitations_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      manager_report_sections: {
        Row: {
          completed: boolean
          data: Json
          id: string
          report_id: string
          section_def_id: string
        }
        Insert: {
          completed?: boolean
          data?: Json
          id?: string
          report_id: string
          section_def_id: string
        }
        Update: {
          completed?: boolean
          data?: Json
          id?: string
          report_id?: string
          section_def_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "manager_report_sections_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "manager_reports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "manager_report_sections_section_def_id_fkey"
            columns: ["section_def_id"]
            isOneToOne: false
            referencedRelation: "report_section_defs"
            referencedColumns: ["id"]
          },
        ]
      }
      manager_reports: {
        Row: {
          branch_id: string
          closed_at: string | null
          closed_by: string | null
          created_at: string
          created_by: string | null
          date: string
          id: string
          org_id: string
          status: Database["public"]["Enums"]["manager_report_status"]
        }
        Insert: {
          branch_id: string
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          created_by?: string | null
          date?: string
          id?: string
          org_id: string
          status?: Database["public"]["Enums"]["manager_report_status"]
        }
        Update: {
          branch_id?: string
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          created_by?: string | null
          date?: string
          id?: string
          org_id?: string
          status?: Database["public"]["Enums"]["manager_report_status"]
        }
        Relationships: [
          {
            foreignKeyName: "manager_reports_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "manager_reports_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          created_at: string
          id: string
          org_id: string
          payload: Json
          read_at: string | null
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          org_id: string
          payload?: Json
          read_at?: string | null
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          org_id?: string
          payload?: Json
          read_at?: string | null
          type?: Database["public"]["Enums"]["notification_type"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      org_members: {
        Row: {
          created_at: string
          org_id: string
          role: Database["public"]["Enums"]["org_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          org_id: string
          role?: Database["public"]["Enums"]["org_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          org_id?: string
          role?: Database["public"]["Enums"]["org_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "org_members_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "org_members_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          industry: string | null
          is_public_demo: boolean
          name: string
          slug: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          industry?: string | null
          is_public_demo?: boolean
          name: string
          slug: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          industry?: string | null
          is_public_demo?: boolean
          name?: string
          slug?: string
        }
        Relationships: []
      }
      products: {
        Row: {
          active: boolean
          category: string | null
          created_at: string
          id: string
          name: string
          org_id: string
          unit: string
        }
        Insert: {
          active?: boolean
          category?: string | null
          created_at?: string
          id?: string
          name: string
          org_id: string
          unit?: string
        }
        Update: {
          active?: boolean
          category?: string | null
          created_at?: string
          id?: string
          name?: string
          org_id?: string
          unit?: string
        }
        Relationships: [
          {
            foreignKeyName: "products_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          full_name: string | null
          id: string
          phone: string | null
          username: string | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          full_name?: string | null
          id: string
          phone?: string | null
          username?: string | null
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          full_name?: string | null
          id?: string
          phone?: string | null
          username?: string | null
        }
        Relationships: []
      }
      report_section_defs: {
        Row: {
          created_at: string
          fields: Json
          id: string
          is_revenue_source: boolean
          name: string
          org_id: string
          required: boolean
          sort: number
        }
        Insert: {
          created_at?: string
          fields?: Json
          id?: string
          is_revenue_source?: boolean
          name: string
          org_id: string
          required?: boolean
          sort?: number
        }
        Update: {
          created_at?: string
          fields?: Json
          id?: string
          is_revenue_source?: boolean
          name?: string
          org_id?: string
          required?: boolean
          sort?: number
        }
        Relationships: [
          {
            foreignKeyName: "report_section_defs_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      revenue_entries: {
        Row: {
          amount: number
          branch_id: string
          created_at: string
          created_by: string | null
          date: string
          id: string
          note: string | null
          org_id: string
          source: string
        }
        Insert: {
          amount?: number
          branch_id: string
          created_at?: string
          created_by?: string | null
          date?: string
          id?: string
          note?: string | null
          org_id: string
          source?: string
        }
        Update: {
          amount?: number
          branch_id?: string
          created_at?: string
          created_by?: string | null
          date?: string
          id?: string
          note?: string | null
          org_id?: string
          source?: string
        }
        Relationships: [
          {
            foreignKeyName: "revenue_entries_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "revenue_entries_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      shift_templates: {
        Row: {
          branch_id: string
          from_time: string
          id: string
          needed: number
          org_id: string
          position: string | null
          to_time: string
          weekday: number
        }
        Insert: {
          branch_id: string
          from_time: string
          id?: string
          needed?: number
          org_id: string
          position?: string | null
          to_time: string
          weekday: number
        }
        Update: {
          branch_id?: string
          from_time?: string
          id?: string
          needed?: number
          org_id?: string
          position?: string | null
          to_time?: string
          weekday?: number
        }
        Relationships: [
          {
            foreignKeyName: "shift_templates_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shift_templates_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      shifts: {
        Row: {
          branch_id: string
          created_at: string
          created_by: string | null
          ends_at: string
          id: string
          note: string | null
          org_id: string
          position: string | null
          published: boolean
          starts_at: string
          user_id: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          created_by?: string | null
          ends_at: string
          id?: string
          note?: string | null
          org_id: string
          position?: string | null
          published?: boolean
          starts_at: string
          user_id: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          created_by?: string | null
          ends_at?: string
          id?: string
          note?: string | null
          org_id?: string
          position?: string | null
          published?: boolean
          starts_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "shifts_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shifts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_levels: {
        Row: {
          branch_id: string
          org_id: string
          product_id: string
          qty: number
          updated_at: string
        }
        Insert: {
          branch_id: string
          org_id: string
          product_id: string
          qty?: number
          updated_at?: string
        }
        Update: {
          branch_id?: string
          org_id?: string
          product_id?: string
          qty?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_levels_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_levels_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_levels_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_movements: {
        Row: {
          branch_id: string
          created_at: string
          created_by: string | null
          doc_ref: string | null
          id: string
          note: string | null
          org_id: string
          product_id: string
          qty_delta: number
          supplier_id: string | null
          type: Database["public"]["Enums"]["stock_movement_type"]
        }
        Insert: {
          branch_id: string
          created_at?: string
          created_by?: string | null
          doc_ref?: string | null
          id?: string
          note?: string | null
          org_id: string
          product_id: string
          qty_delta: number
          supplier_id?: string | null
          type: Database["public"]["Enums"]["stock_movement_type"]
        }
        Update: {
          branch_id?: string
          created_at?: string
          created_by?: string | null
          doc_ref?: string | null
          id?: string
          note?: string | null
          org_id?: string
          product_id?: string
          qty_delta?: number
          supplier_id?: string | null
          type?: Database["public"]["Enums"]["stock_movement_type"]
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      stocktake_items: {
        Row: {
          branch_id: string
          counted_qty: number | null
          created_at: string
          expected_qty: number
          id: string
          org_id: string
          product_id: string
          stocktake_id: string
        }
        Insert: {
          branch_id: string
          counted_qty?: number | null
          created_at?: string
          expected_qty?: number
          id?: string
          org_id: string
          product_id: string
          stocktake_id: string
        }
        Update: {
          branch_id?: string
          counted_qty?: number | null
          created_at?: string
          expected_qty?: number
          id?: string
          org_id?: string
          product_id?: string
          stocktake_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stocktake_items_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stocktake_items_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stocktake_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stocktake_items_stocktake_id_fkey"
            columns: ["stocktake_id"]
            isOneToOne: false
            referencedRelation: "stocktakes"
            referencedColumns: ["id"]
          },
        ]
      }
      stocktakes: {
        Row: {
          branch_id: string
          closed_at: string | null
          closed_by: string | null
          created_at: string
          created_by: string | null
          id: string
          note: string | null
          org_id: string
          status: Database["public"]["Enums"]["stocktake_status"]
        }
        Insert: {
          branch_id: string
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          org_id: string
          status?: Database["public"]["Enums"]["stocktake_status"]
        }
        Update: {
          branch_id?: string
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          org_id?: string
          status?: Database["public"]["Enums"]["stocktake_status"]
        }
        Relationships: [
          {
            foreignKeyName: "stocktakes_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stocktakes_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      subscriptions: {
        Row: {
          created_at: string
          current_period_end: string | null
          id: string
          org_id: string
          plan: Database["public"]["Enums"]["plan"]
          status: string
        }
        Insert: {
          created_at?: string
          current_period_end?: string | null
          id?: string
          org_id: string
          plan?: Database["public"]["Enums"]["plan"]
          status?: string
        }
        Update: {
          created_at?: string
          current_period_end?: string | null
          id?: string
          org_id?: string
          plan?: Database["public"]["Enums"]["plan"]
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      suppliers: {
        Row: {
          contact_name: string | null
          created_at: string
          email: string | null
          id: string
          name: string
          note: string | null
          org_id: string
          phone: string | null
        }
        Insert: {
          contact_name?: string | null
          created_at?: string
          email?: string | null
          id?: string
          name: string
          note?: string | null
          org_id: string
          phone?: string | null
        }
        Update: {
          contact_name?: string | null
          created_at?: string
          email?: string | null
          id?: string
          name?: string
          note?: string | null
          org_id?: string
          phone?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "suppliers_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      task_assignees: {
        Row: {
          created_at: string
          task_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          task_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          task_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_assignees_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      task_checklist_items: {
        Row: {
          done: boolean
          done_at: string | null
          done_by: string | null
          id: string
          label: string
          sort: number
          task_id: string
        }
        Insert: {
          done?: boolean
          done_at?: string | null
          done_by?: string | null
          id?: string
          label: string
          sort?: number
          task_id: string
        }
        Update: {
          done?: boolean
          done_at?: string | null
          done_by?: string | null
          id?: string
          label?: string
          sort?: number
          task_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_checklist_items_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      task_comments: {
        Row: {
          attachments: Json
          author_id: string
          body: string
          branch_id: string
          created_at: string
          id: string
          mentions: string[]
          org_id: string
          task_id: string
        }
        Insert: {
          attachments?: Json
          author_id?: string
          body: string
          branch_id: string
          created_at?: string
          id?: string
          mentions?: string[]
          org_id: string
          task_id: string
        }
        Update: {
          attachments?: Json
          author_id?: string
          body?: string
          branch_id?: string
          created_at?: string
          id?: string
          mentions?: string[]
          org_id?: string
          task_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_comments_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_comments_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_comments_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      task_links: {
        Row: {
          created_at: string
          created_by: string | null
          linked_task_id: string
          task_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          linked_task_id: string
          task_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          linked_task_id?: string
          task_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_links_linked_task_id_fkey"
            columns: ["linked_task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_links_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          branch_id: string
          created_at: string
          created_by: string | null
          description: string | null
          due_at: string | null
          id: string
          org_id: string
          position: number
          priority: Database["public"]["Enums"]["task_priority"]
          status: Database["public"]["Enums"]["task_status"]
          title: string
          updated_at: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          due_at?: string | null
          id?: string
          org_id: string
          position?: number
          priority?: Database["public"]["Enums"]["task_priority"]
          status?: Database["public"]["Enums"]["task_status"]
          title: string
          updated_at?: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          due_at?: string | null
          id?: string
          org_id?: string
          position?: number
          priority?: Database["public"]["Enums"]["task_priority"]
          status?: Database["public"]["Enums"]["task_status"]
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tasks_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      apply_industry_preset: {
        Args: { _industry: string; _org_id: string }
        Returns: undefined
      }
      close_stocktake: { Args: { _stocktake_id: string }; Returns: undefined }
      copy_week_shifts: {
        Args: {
          from_week_start: string
          p_branch_id: string
          to_week_start: string
        }
        Returns: number
      }
      create_organization:
        | {
            Args: { _name: string }
            Returns: {
              created_at: string
              created_by: string | null
              id: string
              industry: string | null
              is_public_demo: boolean
              name: string
              slug: string
            }
            SetofOptions: {
              from: "*"
              to: "organizations"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
            Args: { _industry: string; _name: string }
            Returns: {
              created_at: string
              created_by: string | null
              id: string
              industry: string | null
              is_public_demo: boolean
              name: string
              slug: string
            }
            SetofOptions: {
              from: "*"
              to: "organizations"
              isOneToOne: true
              isSetofReturn: false
            }
          }
      seed_demo_samples: {
        Args: { _org_id: string; _owner_id: string }
        Returns: undefined
      }
    }
    Enums: {
      branch_role: "manager" | "employee"
      chat_channel_type: "org" | "branch" | "custom"
      cost_source: "manual" | "stock" | "payroll"
      day_note_severity: "info" | "issue"
      manager_report_status: "draft" | "closed"
      notification_type:
        | "task_assigned"
        | "mentioned"
        | "comment_on_my_task"
        | "task_due_soon"
        | "shift_published"
        | "stock_low"
      org_role: "owner" | "admin" | "member"
      plan: "demo" | "starter" | "pro" | "network"
      stock_movement_type:
        | "delivery"
        | "usage"
        | "waste"
        | "correction"
        | "transfer"
      stocktake_status: "draft" | "closed"
      task_priority: "low" | "normal" | "high" | "urgent"
      task_status: "todo" | "in_progress" | "done"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      branch_role: ["manager", "employee"],
      chat_channel_type: ["org", "branch", "custom"],
      cost_source: ["manual", "stock", "payroll"],
      day_note_severity: ["info", "issue"],
      manager_report_status: ["draft", "closed"],
      notification_type: [
        "task_assigned",
        "mentioned",
        "comment_on_my_task",
        "task_due_soon",
        "shift_published",
        "stock_low",
      ],
      org_role: ["owner", "admin", "member"],
      plan: ["demo", "starter", "pro", "network"],
      stock_movement_type: [
        "delivery",
        "usage",
        "waste",
        "correction",
        "transfer",
      ],
      stocktake_status: ["draft", "closed"],
      task_priority: ["low", "normal", "high", "urgent"],
      task_status: ["todo", "in_progress", "done"],
    },
  },
} as const

