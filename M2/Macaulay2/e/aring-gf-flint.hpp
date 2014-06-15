// Copyright 2014 Michael E. Stillman

#ifndef _aring_gf_flint_hpp_
#define _aring_gf_flint_hpp_

#include <flint/fq_zech.h>
#include <flint/flint.h>
#include "aring.hpp"
#include "buffer.hpp"
#include "ringelem.hpp"
#include <vector>

class PolynomialRing;
class RingElement;

namespace M2 {

/**
\ingroup rings
*/

  class ARingGFFlint : public RingInterface
  {
  public:
    static const RingID ringID = ring_GFFlintZech;
    typedef fq_zech_struct ElementType;
    typedef ElementType elem;

    ARingGFFlint(const PolynomialRing &R,
                    const ring_elem a);

    ~ARingGFFlint();

    const fq_zech_ctx_struct* flintContext() const { return mContext; }
    long characteristic() const { return mCharacteristic; }
    long dimension() const { return mDimension; }

    const PolynomialRing& originalRing() const { return mOriginalRing; }

    void getGenerator(ElementType& result_gen) const;

    void text_out(buffer &o) const;

  private:
    fq_zech_ctx_t mContext;
    fq_nmod_ctx_t mBigContext;

    const PolynomialRing& mOriginalRing; // This is a quotient ring k[a]/f(a).
    const RingElement* mPrimitiveElement; // element in the original ring
    ulong* mPPowers; // array 0..mDimension of powers of mCharacteristic (mod 2^64)
    long mCharacteristic;
    long mDimension;
    mutable flint_rand_t mRandomState;

    mutable ElementType mCachedGenerator;
    mutable bool mGeneratorComputed;

    ////////////////////////////////
    /// Arithmetic functions ///////
    ////////////////////////////////

  public:
    unsigned long computeHashValue(const elem& a) const 
    { 
      return a.value;
    }

    void to_ring_elem(ring_elem &result, const ElementType &a) const
    {
      // we only use this data type for GF's smaller than 32 bits, since
      // this class creates lookup tables that are way too big otherwise.
      result.int_val = static_cast<int>(a.value); 
    }

    void from_ring_elem(ElementType &result, const ring_elem &a) const
    {
      result.value = a.int_val;
    }

    bool is_unit(const ElementType& f) const { return not is_zero(f); }
    bool is_zero(const ElementType& f) const { return fq_zech_is_zero(&f, mContext); }
    bool is_equal(const ElementType& f, const ElementType& g) const { return fq_zech_equal(&f, &g, mContext); }

    int compare_elems(const ElementType& f, const ElementType& g) const;

    void copy(ElementType& result, const ElementType& a) const { fq_zech_set(&result, &a, mContext); }
    void init(ElementType& result) const { fq_zech_init2(&result, mContext); }
    void init_set(ElementType& result, const ElementType& a) const { init(result); copy(result, a); }
    void set(ElementType& result, const ElementType& a) const { copy(result, a); }
    void set_zero(ElementType& result) const { fq_zech_zero(&result, mContext); }
    void clear(ElementType& result) const { fq_zech_clear(&result, mContext); }
    
    void set_from_long(ElementType& result, long a) const {
      long a1 = a % characteristic();
      if (a1 < 0) a1 += characteristic();
      fq_zech_set_ui(&result, a1, mContext);
    }

    void set_var(ElementType& result, int v) const 
    { 
      if (v != 0) set_from_long(result, 1);
      std::vector<long> poly = {0,1};
      fromSmallIntegerCoefficients(result, poly);
      //printf("variable is %lu\n", result.value);
    }

    void set_from_mpz(ElementType& result, mpz_ptr a) const {
      int b = static_cast<int>(mpz_fdiv_ui(a, characteristic()));
      set_from_long(result, b);
    }

    void set_from_mpq(ElementType& result, mpq_ptr a) const {
      ElementType n, d;
      init(n);
      init(d);
      set_from_mpz(n, mpq_numref(a));
      set_from_mpz(d, mpq_denref(a));
      M2_ASSERT(not is_zero(d));  //TODO actually: we need to check for this...
      divide(result,n,d);
    }

    bool set_from_BigReal(ElementType& result, gmp_RR a) const { return false; }
    
    void negate(ElementType& result, const ElementType& a) const { fq_zech_neg(&result, &a, mContext); }

    void invert(ElementType& result, const ElementType& a) const { 
      M2_ASSERT(not is_zero(a)); 
      fq_zech_inv(&result, &a, mContext); 
    }

    void add(ElementType& result, const ElementType& a, const ElementType& b) const { 
      fq_zech_add(&result, &a, &b, mContext); 
      //printf("zech add %lu + %lu = %lu\n", a.value, b.value, result.value);
    }

    void subtract(ElementType& result, const ElementType& a, const ElementType& b) const { fq_zech_sub(&result, &a, &b, mContext); }

    void subtract_multiple(ElementType& result, const ElementType& a, const ElementType& b) const
    {
      ElementType c;
      init(c);
      mult(c,a,b);
      subtract(result,result,c);
      clear(c);
    }

    void mult(ElementType& result, const ElementType& a, const ElementType& b) const 
    { 
      fq_zech_mul(&result, &a, &b, mContext); 
    }

    void divide(ElementType& result, const ElementType& a, const ElementType& b) const 
    {
      // We need to handle the case when result is a, or b.
      // This is why we use the temporary value 'c'.
      ElementType c;
      init(c);
#if 0
      printf("entering divide\n");
      printf("  a = ");
      fq_zech_print_pretty(&a, mContext);
      printf("\n  b = ");
      fq_zech_print_pretty(&b, mContext);
#endif
      M2_ASSERT(not is_zero(b));
      invert(c,b); 
#if 0
      printf("\n  1/b = ");
      fq_zech_print_pretty(&c, mContext);
#endif
      mult(result,c,a); 
#if 0
      printf("\n  a/b = ");
      fq_zech_print_pretty(&result, mContext);
      printf("\n");
#endif
      clear(c);
    }

    void power(ElementType& result, const ElementType& a, int n) const
    {
      if (is_zero(a)) set_zero(result);
      else if (n < 0)
        {
          invert(result, a);
          fq_zech_pow_ui(&result, &result, -n, mContext);
        }
      else
        fq_zech_pow_ui(&result, &a, n, mContext);
    }

    void power_mpz(ElementType& result, const ElementType& a, mpz_ptr n) const
    {
      if (is_zero(a)) 
        {
          set_zero(result);
          return;
        }
      bool neg = false;
      if (mpz_sgn(n) < 0)
        {
          neg = true;
          mpz_neg(n,n);
          invert(result, a);
        }
      else copy(result, a);

      fmpz_t fn;
      fmpz_init_set_readonly(fn, n);
      fq_zech_pow(&result, &result, fn, mContext);
      fmpz_clear_readonly(fn);
      if (neg) mpz_neg(n,n);
    }

    void swap(ElementType &a, ElementType &b) const
    {
      fq_zech_swap(&a, &b, mContext);
    }

    void elem_text_out(buffer &o,
                       const ElementType& a,
                       bool p_one=true,
                       bool p_plus=false,
                       bool p_parens=false) const;

    void syzygy(const ElementType& a, const ElementType& b,
                ElementType &x, ElementType &y) const
    // returns x,y s.y. x*a + y*b == 0.
    // if possible, x is set to 1.
    // no need to consider the case a==0 or b==0.
    {
      M2_ASSERT(not is_zero(a));
      M2_ASSERT(not is_zero(b));
      set_from_long(x, 1);
      divide(y,a,b);
      negate(y,y);
    }

    void random(ElementType &result) const
    {
      //      printf("calling ARingGFFlint::random\n");
      fq_zech_randtest(&result, mRandomState, mContext);
    }

    void fromSmallIntegerCoefficients(ElementType& result, const std::vector<long>& poly) const;

    void getSmallIntegerCoefficients(const ElementType& a, std::vector<long>& poly) const;

    bool promote(const Ring *Rf, const ring_elem f, ElementType& result) const;

    void lift_to_original_ring(ring_elem& result, const ElementType& f) const;
    // GF specific routine, used in getRepresentation

    bool lift(const Ring *Rg, const ElementType& f, ring_elem &result) const;

    // map : this --> target(map)
    //       primelem --> map->elem(first_var)
    // evaluate map(f)
    void eval(const RingMap *map, const ElementType& f, int first_var, ring_elem &result) const;

  };

};

#endif
// Local Variables:
// compile-command: "make -C $M2BUILDDIR/Macaulay2/e "
// indent-tabs-mode: nil
// End: